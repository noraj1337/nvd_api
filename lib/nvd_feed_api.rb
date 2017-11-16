# @author Alexandre ZANNI <alexandre.zanni@engineer.com>

require 'net/https'
require 'nokogiri'

# The class that parse NVD website to get information.
# @example Initialize a NVDFeedScraper object, get the feeds and see them:
#   scraper = NVDFeedScraper.new
#   scraper.scrap
#   scraper.available_feeds
#   scraper.feeds
#   scraper.feeds("CVE-2007")
#   cve2007, cve2015 = scraper.feeds("CVE-2007", "CVE-2015")
class NVDFeedScraper
  # The NVD url where is located the data feeds.
  URL = 'https://nvd.nist.gov/vuln/data-feeds'.freeze

  # Feed object.
  class Feed
    # @return [String] the name of the feed.
    # @example
    #   'CVE-2007'
    attr_reader :name

    # @return [String] the last update date of the feed.
    # @example
    #   '10/19/2017 3:27:02 AM -04:00'
    attr_reader :updated

    # @return [String] the URL of the metadata file of the feed.
    # @example
    #   'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2007.meta'
    attr_reader :meta

    # @return [String] the URL of the gz archive of the feed.
    # @example
    #   'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2007.json.gz'
    attr_reader :gz

    # @return [String] the URL of the zip archive of the feed.
    # @example
    #   'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2007.json.zip'
    attr_reader :zip

    # A new instance of Feed.
    # @param name [String] see {#name}.
    # @param updated [String] see {#updated}.
    # @param meta [String] see {#meta}.
    # @param gz [String] see {#gz}.
    # @param zip [String] see {#zip}.
    def initialize(name, updated, meta, gz, zip)
      @name = name
      @updated = updated
      @meta = meta
      @gz = gz
      @zip = zip
    end
  end

  def initialize
    @url = URL
    @feeds = nil
  end

  # Scrap / parse the website to get the feeds and fill the {#feeds} attribute.
  # @return [Integer] Returns +0+ when there is no error.
  def scrap
    uri = URI(@url)
    html = Net::HTTP.get(uri)

    doc = Nokogiri::HTML(html)
    @feeds = []
    doc.css('h3#JSON_FEED ~ div.row:first-of-type table.xml-feed-table > tbody > tr[data-testid$=desc]').each do |tr|
      name = tr.css('td')[0].text
      updated = tr.css('td')[1].text
      meta = tr.css('td')[2].css('> a').attr('href').value
      gz = tr.css('+ tr > td > a').attr('href').value
      zip = tr.css('+ tr + tr > td > a').attr('href').value
      @feeds.push(Feed.new(name, updated, meta, gz, zip))
    end
  end

  # Return feeds. Can only be called after {#scrap}.
  # @overload feeds
  #   All the feeds.
  #   @return [Array<Feed>] Attributes of all feeds. It's an array of {Feed} object.
  # @overload feeds(feed)
  #   One feed and its attributes.
  #   @param feed [String] Feed name as written on NVD website. Names can be obtains with {#available_feeds}.
  #   @return [Feed] Attributes of one feed. It's a {Feed} object.
  # @overload feeds(feed, feed)
  #   List of feeds and their attributes.
  #   @param feed [String] Feed name as written on NVD website. Names can be obtains with {#available_feeds}.
  #   @return [Array<Feed>] Attributes of a list of feeds. It's an array of {Feed} object.
  # @example
  #   scraper.feeds => all feeds
  #   scraper.feeds('CVE-2010') => return only CVE-2010 feed
  #   scraper.feeds("CVE-2005", "CVE-2002") => return CVE-2005 and CVE-2002 feeds
  #   scraper.feeds("wrong") => empty array
  def feeds(*arg_feeds)
    return_value = nil
    if arg_feeds.empty?
      return_value = @feeds
    elsif arg_feeds.length == 1
      @feeds.each do |feed| # feed is an object
        return_value = feed if arg_feeds.include?(feed.name)
      end
      # if nothing found return nil
    else
      matched_feeds = []
      @feeds.each do |feed| # feed is an object
        matched_feeds.push(feed) if arg_feeds.include?(feed.name)
      end
      return_value = matched_feeds
    end
    return return_value
  end

  # Return a list with the name of all available feeds. Returned feed names can be use as argument for {#feeds} method. Can only be called after {#scrap}.
  # @return [Array<String>] List with the name of all available feeds.
  # @example
  #   scraper.available_feeds => ["CVE-Modified", "CVE-Recent", "CVE-2017", "CVE-2016", "CVE-2015", "CVE-2014", "CVE-2013", "CVE-2012", "CVE-2011", "CVE-2010", "CVE-2009", "CVE-2008", "CVE-2007", "CVE-2006", "CVE-2005", "CVE-2004", "CVE-2003", "CVE-2002"]
  def available_feeds
    feed_names = []
    @feeds.each do |feed| # feed is an objet
      feed_names.push(feed.name)
    end
    feed_names
  end

  # Manage the meta file from a feed.
  #
  # == Usage
  #
  # @example
  #   s = NVDFeedScraper.new
  #   s.scrap
  #   metaUrl = s.feeds("CVE-2014").meta
  #   m = NVDFeedScraper::Meta.new
  #   m.url = metaUrl
  #   m.parse
  #   m.sha256
  #
  # Several ways to set the url:
  #
  #   m = NVDFeedScraper::Meta.new(metaUrl)
  #   m.parse
  #   # or
  #   m = NVDFeedScraper::Meta.new
  #   m.url = metaUrl
  #   m.parse
  #   # or
  #   m = NVDFeedScraper::Meta.new
  #   m.parse(metaUrl)
  class Meta
    # {Meta} last modified date getter
    # @return [String] the last modified date and time.
    # @example
    #   '2017-10-19T03:27:02-04:00'
    attr_reader :last_modified_date

    # {Meta} JSON size getter
    # @return [String] the size of the JSON file uncompressed.
    # @example
    #   '29443314'
    attr_reader :size

    # {Meta} zip size getter
    # @return [String] the size of the zip file.
    # @example
    #   '2008493'
    attr_reader :zip_size

    # {Meta} gz size getter
    # @return [String] the size of the gz file.
    # @example
    #   '2008357'
    attr_reader :gz_size

    # {Meta} JSON sha256 getter
    # @return [String] the SHA256 value of the uncompressed JSON file.
    # @example
    #   '33ED52D451692596D644F23742ED42B4E350258B11ACB900F969F148FCE3777B'
    attr_reader :sha256

    # @param url [String, nil] see {Feed#meta}.
    def initialize(url = nil)
      @url = url
    end

    # {Meta} URL getter.
    # @return [String] The URL of the meta file of the feed.
    attr_reader :url

    # {Meta} URL setter.
    # @param url [String] see {Feed#meta}.
    def url=(url)
      @url = url
      @last_modified_date = @size = @zip_size = @gz_size = @sha256 = nil
    end

    # Parse the meta file from the URL and set the attributes.
    # @overload parse
    #   Parse the meta file from the URL and set the attributes.
    #   @return [Integer] Returns +0+ when there is no error.
    # @overload parse(url)
    #   Set the URL of the meta file of the feed and
    #   parse the meta file from the URL and set the attributes.
    #   @param url [String] see {Feed.meta}
    #   @return [Integer] Returns +0+ when there is no error.
    def parse(*arg)
      if arg.empty?
      elsif arg.length == 1 # arg = url
        self.url = arg[0]
      else
        raise 'Too much arguments'
      end

      raise "Can't parse if the URL is empty" if @url.nil?
      uri = URI(@url)

      meta = Net::HTTP.get(uri)

      meta = Hash[meta.split.map { |x| x.split(':', 2) }]

      raise 'no lastModifiedDate attribute found' unless meta['lastModifiedDate']
      raise 'no valid size attribute found' unless /[0-9]+/.match?(meta['size'])
      raise 'no valid zipSize attribute found' unless /[0-9]+/.match?(meta['zipSize'])
      raise 'no valid gzSize attribute found' unless /[0-9]+/.match?(meta['gzSize'])
      raise 'no valid sha256 attribute found' unless /[0-9A-F]{64}/.match?(meta['sha256'])

      @last_modified_date = meta['lastModifiedDate']
      @size = meta['size']
      @zip_size = meta['zipSize']
      @gz_size = meta['gzSize']
      @sha256 = meta['sha256']

      0
    end
  end
end