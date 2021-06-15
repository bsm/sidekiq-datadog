require 'spec_helper'

describe Sidekiq::Middleware::Client::Datadog do
  let(:statsd) { Mock::Statsd.new('localhost', 55555) }
  let(:worker_class) { 'Mock::Worker' }
  let(:tags) do
    ['custom:tag', ->(worker_class, *) { "worker:#{worker_class[1..2]}" }]
  end
  let(:options) { {} }

  before do
    statsd.messages.clear
  end

  subject { described_class.new(hostname: 'test.host', statsd: statsd, tags: tags, **options) }

  it 'should send an increment event for each job enqueued' do
    subject.call(worker_class, {}, 'default', nil) { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job_enqueued:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:mock/worker,'\
        'queue:default',
    ])
  end

  it 'should support wrappers' do
    subject.call(worker_class, { 'wrapped' => 'wrap' }, nil, nil) { 'ok' }
    expect(statsd.messages).to eq([
      'sidekiq.job_enqueued:1|c|#custom:tag,worker:oc,host:test.host,env:test,name:wrap',
    ])
  end

  context 'with a dynamic tag list' do
    let(:tags) do
      ['custom:tag', ->(_w, j, *) { j['args'].map {|n| "arg:#{n}" } }]
    end

    it 'should generate the correct tags' do
      subject.call(worker_class, { 'args' => [1, 2] }, 'default', nil) { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job_enqueued:1|c|#custom:tag,arg:1,arg:2,host:test.host,env:test,name:mock/worker,'\
          'queue:default',
      ])
    end
  end

  context 'with a list of skipped tags' do
    let(:tags) { [] }
    let(:options) { { skip_tags: %i[env host name] } }

    it 'should send metrics without the skipped tags' do
      subject.call(worker_class, {}, 'default', nil) { 'ok' }

      expect(statsd.messages).to eq([
        'sidekiq.job_enqueued:1|c|#queue:default',
      ])
    end
  end

  context 'when sidekiq/api is required' do
    before do
      require 'sidekiq/api'
    end

    it 'should not raise any errors' do
      expect do
        subject.call(worker_class, {}, 'default', nil) { 'ok' }
      end.not_to raise_error
    end
  end
end
