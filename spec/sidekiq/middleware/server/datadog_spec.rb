require 'spec_helper'

describe Sidekiq::Middleware::Server::Datadog do

  let(:statsd) { Mock::Statsd.new(nil, nil, {}, 10000) }
  let(:worker) { Mock::Worker.new }

  before  { statsd.buffer.clear }
  subject { described_class.new hostname: "test.host", statsd: statsd, tags: ["custom:tag", lambda{|w, *| "worker:#{w.class.name[1..2]}" }] }

  it 'should send an increment and timing event for each job run' do
    subject.call(worker, { 'enqueued_at' => 1461881794.9312189 }, 'default') { "ok" }
    expect(statsd.buffer).to eq([
      "sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok",
      "sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok",
      "sidekiq.job.queued_time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok",
    ])
  end

  it 'should support wrappers' do
    subject.call(worker, { 'enqueued_at' => 1461881794.9312189, 'wrapped' => 'wrap'}, nil) { "ok" }
    expect(statsd.buffer).to eq([
      "sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok",
      "sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok",
      "sidekiq.job.queued_time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok",
    ])
  end

  it 'should handle errors' do
    expect(lambda {
      subject.call(worker, {}, nil) {  raise RuntimeError, "doh!" }
    }).to raise_error("doh!")

    expect(statsd.buffer).to eq([
      "sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,status:error,error:runtime",
      "sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,status:error,error:runtime",
    ])
  end

end
