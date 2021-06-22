require 'spec_helper'

describe Sidekiq::Datadog::TagBuilder do
  subject { described_class.new(custom_tags, skip_tags, custom_hostname) }

  let(:custom_tags) { nil }
  let(:worker) { Mock::Worker.new }
  let(:job) { { 'enqueued_at' => 1461881794 } }
  let(:queue) { 'queue_name' }
  let(:error) { nil }
  let(:skip_tags) { nil }
  let(:custom_hostname) { nil }

  it 'builds basic default tags without any parameters' do
    result = subject.build_tags(worker, job, queue, error)

    expect(result).to eql([
      "host:#{Socket.gethostname}",
      'env:test',
      'name:mock/worker',
      'queue:queue_name',
      'status:ok',
    ])
  end

  context 'with custom hostname' do
    let(:custom_hostname) { 'myhostname' }

    it 'reports the custom hostname' do
      result = subject.build_tags(worker, job, queue, error)
      expect(result).to include('host:myhostname')
    end
  end

  context 'with custom tags' do
    let(:custom_tags) { ['custom:tag', ->(w, *) { "worker:#{w.class.name[1..2]}" }] }

    it 'reports the custom tags, fixed and Procs' do
      result = subject.build_tags(worker, job, queue, error)
      expect(result).to include('custom:tag')
      expect(result).to include('worker:oc')
    end
  end

  context 'with skipped tags' do
    let(:skip_tags) { %w[name env] }

    it "doesn't output the skipped tags" do
      result = subject.build_tags(worker, job, queue, error)
      result_keys = result.map {|t| t.split(':').first }

      expect(result_keys).not_to include('name')
      expect(result_keys).not_to include('env')
    end
  end

  context 'with a wrapped job' do
    let(:job) { { 'wrapped' => 'Module::WrappedJobName' } }

    it 'reports the wrapped job name' do
      result = subject.build_tags(worker, job, queue, error)
      expect(result).to include('name:module/wrapped_job_name')
    end
  end

  context 'with an error' do
    let(:error) { ArgumentError.new }

    it 'reports the error class, and status' do
      result = subject.build_tags(worker, job, queue, error)
      expect(result).to include('error:argument')
      expect(result).to include('status:error')
    end
  end

  context 'with a worker_class instead of a Worker object' do
    let(:worker_class) { 'Module::Worker' }

    it 'reports the error class, and status' do
      result = subject.build_tags(worker_class, job, queue, error)
      expect(result).to include('name:module/worker')
    end
  end
end
