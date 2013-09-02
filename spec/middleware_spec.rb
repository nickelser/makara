require 'ostruct'
require 'spec_helper'

describe Makara2::Middleware do

  let(:app){ 
    lambda{|env|
      proxy.query(env[:query] || 'select * from users')
      [200, {}, ["#{Makara2::Context.get_current}-#{Makara2::Context.get_previous}"]]
    }
  }

  let(:env){ {} }
  let(:proxy){ FakeProxy.new(config(1,2)) }
  let(:middleware){ described_class.new(app) }

  let(:key){ Makara2::Middleware::COOKIE_NAME }

  it 'should set the context before the request' do
    Makara2::Context.set_previous 'old'
    Makara2::Context.set_current 'old'

    response = middleware.call(env)
    current, prev = context_from(response)

    expect(current).not_to eq('old')
    expect(prev).not_to eq('old')

    expect(current).to eq(Makara2::Context.get_current)
    expect(prev).to eq(Makara2::Context.get_previous)
  end

  it 'should use the cookie-provided context if present' do
    env['HTTP_COOKIE'] = "#{key}=abcdefg--200; path=/; max-age=5"

    response = middleware.call(env)
    current, prev = context_from(response)

    expect(prev).to eq('abcdefg')
    expect(current).to eq(Makara2::Context.get_current)
    expect(current).not_to eq('abcdefg')
  end

  it 'should set the cookie if master is used' do
    env[:query] = 'update users set name = "phil"'

    status, headers, body = middleware.call(env)

    expect(headers['Set-Cookie']).to eq("#{key}=#{Makara2::Context.get_current}--200; path=/; max-age=5")
  end

  it 'should preserve the same context if the previous request was a redirect' do
    env['HTTP_COOKIE'] = "#{key}=abcdefg--301; path=/; max-age=5"

    response    = middleware.call(env)
    curr, prev  = context_from(response)

    expect(curr).to eq('abcdefg')
    expect(prev).to eq('abcdefg')

    env['HTTP_COOKIE'] = response[1]['Set-Cookie']

    response = middleware.call(env)
    curr2, prev2 = context_from(response)

    expect(prev2).to eq('abcdefg')
    expect(curr2).to eq(Makara2::Context.get_current)
  end

  def context_from(response)
    response[2][0].split('-')
  end

end