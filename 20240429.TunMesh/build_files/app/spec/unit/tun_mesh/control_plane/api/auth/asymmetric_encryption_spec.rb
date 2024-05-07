require 'openssl'

require './spec/helpers/spec_helper'
require './lib/tun_mesh/control_plane/api/auth/asymmetric_encryption/local'
require './lib/tun_mesh/control_plane/api/auth/asymmetric_encryption/remote'

describe TunMesh::ControlPlane::API::Auth::AsymmetricEncryption do
  describe 'ALGORITHM' do
    it 'is RSA' do
      expect(described_class::ALGORITHM).to be(OpenSSL::PKey::RSA)
    end
  end

  let(:local_subject) { described_class::Local.new }
  let(:remote_public_key) { local_subject.public_key }
  let(:remote_subject) { described_class::Remote.new(public_key: remote_public_key) }

  let(:plaintext) { Random.bytes(rand(64..128)) }

  describe '::Local' do
    let(:pub_key_obj) { OpenSSL::PKey::RSA.new(Base64.decode64(local_subject.public_key)) }

    describe '.public_key' do
      it 'returns a base64 encoded RSA key' do
        expect { pub_key_obj }.to_not raise_exception
      end
    end

    describe '.decrypt' do
      it "decrypts ciphertext encrypted with it's public key" do
        ciphertext = Base64.encode64(pub_key_obj.public_encrypt(plaintext))
        expect(local_subject.decrypt(ciphertext: ciphertext)).to eq plaintext
      end

      it 'decrypts ciphertext encrypted by the Remote class' do
        ciphertext = remote_subject.encrypt(payload: plaintext)
        expect(local_subject.decrypt(ciphertext: ciphertext)).to eq plaintext
      end
    end
  end

  describe '::Remote' do
    describe '.encrypt' do
      let(:rsa_private) { OpenSSL::PKey::RSA.generate(2048) }
      let(:remote_public_key) { Base64.encode64(rsa_private.public_key.to_der) }

      it 'encrypts ciphertext with the given public key' do
        ciphertext = remote_subject.encrypt(payload: plaintext)
        expect(rsa_private.decrypt(Base64.decode64(ciphertext))).to eq plaintext
      end
    end
  end
end
