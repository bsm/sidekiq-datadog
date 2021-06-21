require 'spec_helper'

describe Sidekiq::Middleware::Server::Datadog do
  subject { described_class.new(hostname: 'test.host', statsd: statsd, tags: tags, **options) }

  let(:statsd) { Mock::Statsd.new('localhost', 55555) }
  let(:worker) { instance_double('Worker') }
  let(:tags) do
    ['custom:tag', ->(w, *) { "worker:#{w.class.name[1..2]}" }]
  end
  let(:options) { {} }
  let(:enqueued_at) { 1461881794.9312189 }
  let(:expected_queued_time_ms) { 444 }

  before do
    statsd.messages.clear

    clock_gettime_call_count = 0
    expect(Process).to receive(:clock_gettime).twice do
      clock_gettime_call_count += 1
      clock_gettime_call_count == 1 ? 0 : 333
    end

    Timecop.freeze(Time.at(enqueued_at + expected_queued_time_ms.to_f / 1000))
  end

  it 'sends an increment and timing event for each job run' do
    subject.call(worker, { 'enqueued_at' => enqueued_at }, 'default') { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,'\
        'queue:default,status:ok',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,'\
        'queue:default,status:ok',
      "sidekiq.job.queued_time:#{expected_queued_time_ms}|ms|#custom:tag,worker:oc,host:test.host,"\
        'env:test,name:mock/worker,queue:default,status:ok',
    ])
  end

  it 'supports wrappers' do
    subject.call(worker, { 'enqueued_at' => enqueued_at, 'wrapped' => 'wrap' }, nil) { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:wrap,status:ok',
      "sidekiq.job.queued_time:#{expected_queued_time_ms}|ms|#custom:tag,worker:oc,host:test.host,"\
        'env:test,name:wrap,status:ok',
    ])
  end

  it 'handles errors' do
    expect(lambda {
      subject.call(worker, {}, nil) { raise 'doh!' }
    }).to raise_error('doh!')

    expect(statsd.messages).to eq([
      'sidekiq.job:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,'\
        'status:error,error:runtime',
      'sidekiq.job.time:333|ms|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,'\
        'status:error,error:runtime',
    ])
  end

  context 'with a dynamic tag list' do
    let(:tags) do
      ['custom:tag', ->(_w, j, *) { j['args'].map {|n| "arg:#{n}" } }]
    end

    it 'generates the correct tags' do
      subject.call(worker, { 'enqueued_at' => enqueued_at, 'args' => [1, 2] }, 'default') { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job:1|c|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,'\
          'queue:default,status:ok',
        'sidekiq.job.time:333|ms|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,'\
          'queue:default,status:ok',
        "sidekiq.job.queued_time:#{expected_queued_time_ms}|ms|#custom:tag,arg:1,arg:2,"\
          'host:test.host,env:test,name:mock/worker,queue:default,status:ok',
      ])
    end
  end

  context 'with a list of skipped tags' do
    let(:tags) { [] }
    let(:options) { { skip_tags: %i[env host name] } }

    it 'sends metrics without the skipped tags' do
      subject.call(worker, { 'enqueued_at' => 1461881794.9312189 }, 'default') { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job:1|c|#queue:default,status:ok',
        'sidekiq.job.time:333|ms|#queue:default,status:ok',
        "sidekiq.job.queued_time:#{expected_queued_time_ms}|ms|#queue:default,status:ok",
      ])
    end
  end

  context 'when sidekiq/api is required' do
    before do
      require 'sidekiq/api'
    end

    it 'does not raise any errors' do
      expect do
        subject.call(worker, { 'enqueued_at' => enqueued_at }, 'default') { 'ok' }
      end.not_to raise_error
    end
  end
end
