require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/topic'

describe Routemaster::Models::Topic do
  let(:options) {{ name: 'widgets', publisher: 'bob' }}
  subject { described_class.new(options) }

  describe '.new' do
    it 'fails wihtout arguments' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError)
    end

    it 'succeeds in a blank slate' do
      expect(
        described_class.new(name: 'widgets', publisher: 'bob')
      ).to be_a_kind_of(described_class)
    end

    it 'fails if the topic is claimed by another publisher' do
      described_class.new(name: 'widgets', publisher: 'bob')
      expect {
        described_class.new(name: 'widgets', publisher: 'alice')
      }.to raise_error(described_class::TopicClaimedError)
    end
  end

  describe '#destroy' do
    it 'removes the topic' do
      subject.destroy
      expect(described_class.find('widgets')).to be_nil
    end

    it 'is idempotent' do
      subject.destroy
      expect { subject.destroy }.not_to raise_error
    end
  end


  describe 'marshalling' do
    let(:result) { Marshal.load(Marshal.dump(subject)) }

    it 'can be marshalled/unmarshalled' do
      expect(result.name).to eq('widgets')
      expect(result.publisher).to eq('bob')
    end
  end


  describe '#publisher' do
    it 'returns the channel publisher' do
      expect(subject.publisher).to eq('bob')
    end

  end


  describe '#subscribers' do
    it 'returns the list of channel subscribers' do
      expect(subject.subscribers.to_a).to eq([])
    end
  end

  describe '.all' do
    it 'is empty in a blank state' do
      expect(described_class.all).to be_empty
    end

    it 'lists all topics' do
      topic1 = described_class.new(name: 'widgets', publisher: 'john')
      topic2 = described_class.new(name: 'koalas',  publisher: 'john')

      expect(described_class.all).to include(topic1)
      expect(described_class.all).to include(topic2)
    end
  end

  describe '.find' do
    let(:result) { described_class.find('widgets') }
    it 'returns existing topics' do
      subject
      expect(result).to eq(subject)
    end

    it 'returns nil for unknown topics' do
      expect(result).to be_nil
    end

    context 'when the topic is unclaimed' do
      before { options[:publisher] = nil }

      it 'returns the existing topic' do
        subject
        expect(result).to eq(subject)
      end
    end
  end
end
