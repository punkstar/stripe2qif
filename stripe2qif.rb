#!/usr/bin/env ruby

require 'optparse'
require 'date'

module Meanbee
  require 'stripe'
  
  class StripeQif
    def initialize(api_key, from_date, count)
      @qif = Qif.new
      @from_timestamp = DateTime.parse(from_date).strftime('%s')
      @count = count

      Stripe.api_key = api_key
      Stripe.api_version = "2013-08-13"
    end

    def process
      transfers = Stripe::Transfer.all(:count => @count, :date => { :gt => @from_timestamp })

      transfers.each do |transfer|
        date = Time.at(transfer.date).to_datetime.strftime("%F")
        net_amount = transfer.amount.to_f / 100
        fee_amount = transfer.summary.charge_fees.to_f / 100
        currency = transfer.currency.upcase

        @qif.add date, "Transfer on #{date} (Fee: #{fee_amount}#{currency})", net_amount
      end
    end

    def print
      @qif.print
    end
  end
  
  class Qif
    def initialize()
      @items = []
    end
    
    def add(date, desc, amount)
      @items << {
        :date => date,
        :desc => desc,
        :amount => amount
      }
    end
    
    def print
      lines = []
      
      lines << "!Type:Bank"
      
      @items.each do |item|
        lines << 'D' + item[:date]
        lines << 'P' + item[:desc]
        lines << 'M' + item[:desc]
        lines << 'CC'
        lines << 'T' + "%.3f" % item[:amount]
        lines << '^'
      end
      
      lines << "\n" # Empty line
      
      lines.join "\n"
    end
  end
end

options = {}

options[:from] = '01/01/1900'
options[:count] = 100

optparse = OptionParser.new do |opts|
    opts.banner = "Usage: stripe2qif.rb --api-key STRIPE_API_KEY"

    opts.on('--api-key STRIPE_API_KEY', 'Stripe API key, required.') do |f|
        options[:api_key] = f
    end

    opts.on('--from dd/mm/yyyy', 'A date to list all transfers after, exclusive. If not specified, start of time is used.') do |f|
        options[:from] = f
    end

    opts.on('--count COUNT', 'The maximum number of transfers to return.  Maximum is 100, will assume 100 if not provided.') do |f|
        options[:count] = f
    end

    opts.on('-h', '--help', 'Display this screen') do |f| 
        puts opts
        exit
    end 
end

optparse.parse!

begin
    raise OptionParser::MissingArgument if options[:api_key].nil?
rescue
    puts 'Error: Missing required options.'
    puts optparse
    exit 1
end

qif = Meanbee::StripeQif.new(options[:api_key], options[:from], options[:count])
qif.process

puts qif.print
