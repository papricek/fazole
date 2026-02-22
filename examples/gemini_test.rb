# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'ruby_llm'

RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
end

chat = RubyLLM.chat(model: 'gemini-3-flash-preview')
response = chat.ask('What is the meaning of fazole in Czech? Answer in one sentence.')

puts response.content
