require 'spec_helper'

describe Sidekiq::Middleware::Server::Datadog do

  let(:statsd) { Mock::Statsd.new('localhost', 55555) }
  let(:worker) { Mock::Worker.new }
  let(:tags) do
    ['custom:tag', ->(w, *) { "worker:#{w.class.name[1..2]}" }]
  end
  let(:options) { {} }

  before  { statsd.messages.clear }
  subject { described_class.new(hostname: 'test.host', statsd: statsd, tags: tags, **options) }

  it 'should send an increment and timing event for each job run' do
    subject.call(worker, { 'enqueued_at' => 1461881794.9312189 }, 'default') { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
      'sidekiq.job.queued_time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
    ])
  end

  it 'should support wrappers' do
    subject.call(worker, { 'enqueued_at' => 1461881794.9312189, 'wrapped' => 'wrap' }, nil) { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok',
      'sidekiq.job.queued_time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok',
    ])
  end

  it 'should handle errors' do
    expect(lambda {
      subject.call(worker, {}, nil) { raise 'doh!' }
    }).to raise_error('doh!')

    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,status:error,error:runtime',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,status:error,error:runtime',
    ])
  end

  context 'with a dynamic tag list' do
    let(:tags) do
      ['custom:tag', ->(_w, j, *) { j['args'].map {|n| "arg:#{n}" } }]
    end

    it 'should generate the correct tags' do
      subject.call(worker, { 'enqueued_at' => 1461881794.9312189, 'args' => [1, 2] }, 'default') { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job:1|c|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
        'sidekiq.job.time:333|ms|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
        'sidekiq.job.queued_time:333|ms|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,queue:default,status:ok',
      ])
    end
  end

  context 'with a list of skipped tags' do
    let(:tags) { [] }
    let(:options) { { skip_tags: %i[env host name] } }

    it 'should send metrics without the skipped tags' do
      subject.call(worker, { 'enqueued_at' => 1461881794.9312189 }, 'default') { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job:1|c|#queue:default,status:ok',
        'sidekiq.job.time:333|ms|#queue:default,status:ok',
        'sidekiq.job.queued_time:333|ms|#queue:default,status:ok',
      ])
    end
  end
end
