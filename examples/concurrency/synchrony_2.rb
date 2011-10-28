require File.expand_path('../../helper.rb', __FILE__)

require 'em-synchrony'
require 'em-synchrony/em-http'

# Monkey-patch request to use EM::HTTP::Request
module Vacuum
  class Request
    # Performs an asynchronous request with the EM async HTTP client
    def aget(&block)
      http = EM::HttpRequest.new(url).aget
      resp = lambda { Response.new(http.response, http.response_header.status) }
      http.callback { block.call(resp.call) }
      http.errback  { block.call(resp.call) }
    end
  end
end

locales = Vacuum::Locale::LOCALES

locales.each do |locale|
  Vacuum[locale].configure do |c|
    c.key    = AMAZON_KEY
    c.secret = AMAZON_SECRET
    c.tag    = AMAZON_ASSOCIATE_TAG
  end
end

# Really fat requests executed evented and in parallel.
resps = nil
EM.synchrony do
  concurrency = 8

  resps = EM::Synchrony::Iterator.new(locales, concurrency).map do |locale, iter|
    req = Vacuum[locale]
    req << { 'Operation'                       => 'ItemLookup',
             'Version'                         => '2010-11-01',
             'ItemLookup.Shared.IdType'        => 'ASIN',
             'ItemLookup.Shared.Condition'     => 'All',
             'ItemLookup.Shared.MerchantId'    => 'All',
             'ItemLookup.Shared.ResponseGroup' => %w{OfferFull ItemAttributes Images},
             'ItemLookup.1.ItemId'             => Asin[0, 10],
             'ItemLookup.2.ItemId'             => Asin[10, 10] }
    req.aget { |resp| iter.return(resp) }
  end
  EM.stop
end

binding.pry