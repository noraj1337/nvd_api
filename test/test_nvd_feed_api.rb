require 'minitest/autorun'
require 'nvd_feed_api'
require 'date'

class NVDAPITest < Minitest::Test
  def setup
    @s = NVDFeedScraper.new
    @s.scrap # needed for feeds method
  end

  def test_scraper_scrap
    assert_equal(@s.scrap, 0, 'scrap method return nothing')
  end

  def test_scraper_feeds_noarg
    assert_instance_of(Array, @s.feeds, "feeds doesn't return an array") # same as #assert(@s.feeds.instance_of?(Array), 'error')
    refute_empty(@s.feeds, 'feeds returns an empty array')
  end

  def test_scraper_feeds_witharg
    # one arg
    assert_instance_of(NVDFeedScraper::Feed, @s.feeds('CVE-2017'), "feeds doesn't return a Feed object")
    # two args
    assert_instance_of(Array, @s.feeds('CVE-2017', 'CVE-Modified'), "feeds doesn't return an array")
    refute_empty(@s.feeds('CVE-2017', 'CVE-Modified'), 'feeds returns an empty array')
    # array arg
    assert_instance_of(Array, @s.feeds(['CVE-2016', 'CVE-Recent']), "feeds doesn't return an array")
    refute_empty(@s.feeds(['CVE-2016', 'CVE-Recent']), 'feeds returns an empty array')
    # bad arg
    assert_nil(@s.feeds('wrong'), 'feeds')
  end

  def test_scraper_available_feeds
    assert_instance_of(Array, @s.available_feeds, "available_feeds doesn't return an array")
    refute_empty(@s.available_feeds, 'available_feeds returns an empty array')
  end

  def test_scraper_available_cves
    assert_instance_of(Array, @s.available_cves, "available_cves doesn't return an array")
    refute_empty(@s.available_cves, 'available_cves returns an empty array')
  end

  def test_scraper_cve
    # one arg
    assert_instance_of(Hash, @s.cve('CVE-2015-0235'), "cve doesn't return a hash")
    # two args
    assert_instance_of(Array, @s.cve('CVE-2015-0235', 'CVE-2013-3893'), "cve doesn't return an array")
    refute_empty(@s.cve('CVE-2015-0235', 'CVE-2013-3893'), 'cve returns an empty array')
    # array arg
    assert_instance_of(Array, @s.cve(['CVE-2014-0160', 'cve-2009-3555']), "cve doesn't return an array")
    refute_empty(@s.cve(['CVE-2014-0160', 'cve-2009-3555']), 'cve returns an empty array')
    # bad arg
    ## string but not a CVE ID
    assert_raises(RuntimeError) do
      err = @s.cve('e')
      assert_equal(err.message, 'bad CVE name')
    end
    ## correct CVE ID but bad year
    assert_raises(RuntimeError) do
      err = @s.cve('CVE-2001-31337')
      assert_equal(err.message, 'bad CVE year in ["CVE-2001-31337"]')
    end
    ## correct CVE ID and year but unexisting CVE
    assert_nil(@s.cve('CVE-2004-31337'))
    ## correct CVE ID and year but unexisting CVE with array arg
    assert_raises(RuntimeError) do
      err = @s.cve(['CVE-2004-31337', 'CVE-2005-31337'])
      assert_equal(err.message, 'CVE-2005-31337 are unexisting CVEs in this feed')
    end
    ## wrong arg type
    assert_raises(RuntimeError) do
      err = @s.cve(1)
      assert_equal(err.message, 'the provided argument (1) is nor a String or an Array')
    end
  end

  def test_scraper_update_feeds
    f2017, f2016, f_modified = @s.feeds('CVE-2017', 'CVE-2016', 'CVE-Modified')
    # one arg
    # can't use assert_instance_of because there is no boolean class
    assert(%w[TrueClass FalseClass].include?(@s.update_feeds(f2017).class.to_s), "update_feeds doesn't return a boolean")
    # two args
    assert_instance_of(Array, @s.update_feeds(f2017, f2016), "update_feeds doesn't return an array")
    refute_empty(@s.update_feeds(f2017, f2016), 'update_feeds returns an empty array')
    # array arg
    assert_instance_of(Array, @s.update_feeds([f2017, f_modified]), "update_feeds doesn't return an array")
    refute_empty(@s.update_feeds([f2017, f_modified]), 'update_feeds returns an empty array')
    # bad arg
    ## wrong arg type
    assert_raises(RuntimeError) do
      err = @s.update_feeds(1)
      assert_equal(err.message, 'the provided argument 1 is not a Feed or an Array')
    end
    ## empty array
    assert_empty(@s.update_feeds([]))
  end

  def test_feed_default_storage_location
    # save default value / save context
    default_val = NVDFeedScraper::Feed.default_storage_location
    # check type
    assert_instance_of(String, default_val, "default_storage_location doesn't return a string")
    # check new value
    new_val = '/srv/downloads/'
    assert_equal(NVDFeedScraper::Feed.default_storage_location = new_val, new_val, 'the new value was not set properly')
    # put the default value back / restore context
    NVDFeedScraper::Feed.default_storage_location = default_val
  end

  def test_feed_attributes
    name = 'CVE-2010'
    meta_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2010.meta'
    gz_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2010.json.gz'
    zip_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2010.json.zip'
    f = @s.feeds('CVE-2010')
    # Test name
    assert_instance_of(String, f.name, "name doesn't return a string")
    refute_empty(f.name, 'name is empty')
    assert_equal(f.name, name, 'The name of the feed was modified')
    # Test updated
    assert_instance_of(String, f.updated, "updated doesn't return a string")
    refute_empty(f.updated, 'updated is empty')
    # Test meta
    assert_nil(f.meta)
    # Test json_file
    assert_nil(f.json_file)
    # Test gz_url
    assert_instance_of(String, f.gz_url, "gz_url doesn't return a string")
    refute_empty(f.gz_url, 'gz_url is empty')
    assert_equal(f.gz_url, gz_url, 'The gz_url of the feed was modified')
    # Test zip_url
    assert_instance_of(String, f.zip_url, "zip_url doesn't return a string")
    refute_empty(f.zip_url, 'zip_url is empty')
    assert_equal(f.zip_url, zip_url, 'The zip_url url of the feed was modified')
    # Test meta_url
    assert_instance_of(String, f.meta_url, "meta_url doesn't return a string")
    refute_empty(f.meta_url, 'meta_url is empty')
    assert_equal(f.meta_url, meta_url, 'The meta_url url of the feed was modified')
  end

  def test_feed_available_cves
    f = @s.feeds('CVE-2011')
    f.json_pull
    assert_instance_of(Array, f.available_cves, "available_cves doesn't return an array")
    refute_empty(f.available_cves, 'available_cves returns an empty array')
  end

  def test_feed_cve
    f = @s.feeds('CVE-2012')
    f.json_pull
    # one arg
    assert_instance_of(Hash, @s.cve('CVE-2012-4969'), "cve doesn't return a hash")
    # two args
    assert_instance_of(Array, @s.cve('CVE-2012-4969', 'cve-2012-1889'), "cve doesn't return an array")
    refute_empty(@s.cve('CVE-2012-4969', 'cve-2012-1889'), 'cve returns an empty array')
    # array arg
    assert_instance_of(Array, @s.cve(['CVE-2012-4969', 'cve-2012-1889']), "cve doesn't return an array")
    refute_empty(@s.cve(['CVE-2012-4969', 'cve-2012-1889']), 'cve returns an empty array')
    # bad arg
    ## string but not a CVE ID
    assert_raises(RuntimeError) do
      err = @s.cve('e')
      assert_equal(err.message, 'bad CVE name')
    end
    ## correct CVE ID but bad year
    assert_nil(@s.cve('CVE-2004-31337'))
    ## correct CVE ID and but year not in the feed with array arg
    assert_raises(RuntimeError) do
      err = @s.cve(['CVE-2004-31337', 'CVE-2005-31337'])
      assert_equal(err.message, 'CVE-2004-31337, CVE-2005-31337 are unexisting CVEs in this feed')
    end
    ## wrong arg type
    assert_raises(RuntimeError) do
      err = @s.cve(1)
      assert_equal(err.message, 'the provided argument (1) is nor a String or an Array')
    end
  end

  def test_feed_download_gz
    f = @s.feeds('CVE-2013')
    return_value = f.download_gz
    assert_instance_of(String, return_value, "download_gz doesn't return a string")
    refute_empty(return_value, 'download_gz returns an empty string')
    assert(File.file?(return_value), 'download_gz returns an unexisting file')
  end

  def test_feed_download_zip
    f = @s.feeds('CVE-2003')
    return_value = f.download_zip
    assert_instance_of(String, return_value, "download_zip doesn't return a string")
    refute_empty(return_value, 'download_zip returns an empty string')
    assert(File.file?(return_value), 'download_zip returns an unexisting file')
  end

  def test_feed_json_pull
    f = @s.feeds('CVE-2004')
    return_value = f.json_pull
    assert_instance_of(String, return_value, "json_pull doesn't return a string")
    refute_empty(return_value, 'json_pull returns an empty string')
    assert(File.file?(return_value), 'json_pull returns an unexisting file')
  end

  def test_feed_meta_pull
    f = @s.feeds('CVE-2005')
    return_value = f.meta_pull
    assert_instance_of(NVDFeedScraper::Meta, return_value, "meta_pull doesn't return a Meta object")
  end

  def test_meta_parse_noarg
    m = NVDFeedScraper::Meta.new('https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2015.meta')
    assert_equal(m.parse, 0, 'parse method return nothing')
  end

  def test_meta_parse_witharg
    m = NVDFeedScraper::Meta.new
    meta_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2015.meta'
    assert_equal(m.parse(meta_url), 0, 'parse method return nothing')
  end

  def test_meta_url_setter
    m = NVDFeedScraper::Meta.new
    meta_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2015.meta'
    assert_equal(m.url = meta_url, meta_url, 'the meta URL is not set correctly')
  end

  def test_meta_attributes
    m = NVDFeedScraper::Meta.new
    meta_url = 'https://static.nvd.nist.gov/feeds/json/cve/1.0/nvdcve-1.0-2015.meta'
    m.url = meta_url
    m.parse
    # Test gz_size
    assert_instance_of(String, m.gz_size, "Meta gz_size method doesn't return a string")
    assert(m.gz_size.match?(/[0-9]+/), 'Meta gz_size is not an integer')
    # Test last_modified_date
    assert_instance_of(String, m.last_modified_date, "Meta last_modified_date method doesn't return a string")
    ## Date and time of day for calendar date (extended) '%FT%T%:z'
    assert(Date.rfc3339(m.last_modified_date), 'Meta last_modified_date is not a rfc3339 date')
    # Test sha256
    assert_instance_of(String, m.sha256, "Meta sha256 method doesn't return a string")
    assert(m.sha256.match?(/[0-9A-F]{64}/), 'Meta sha256 is not a sha256 string matching /[0-9A-F]{64}/')
    # Test size
    assert_instance_of(String, m.size, "Meta size method doesn't return a string")
    assert(m.size.match?(/[0-9]+/), 'Meta size is not an integer')
    # Test url
    assert_instance_of(String, m.url, "Meta url method doesn't return a string")
    assert_equal(m.url, meta_url, 'The Meta url was modified')
    # Test zip_size
    assert_instance_of(String, m.zip_size, "Meta zip_size method doesn't return a string")
    assert(m.zip_size.match?(/[0-9]+/), 'Meta zip_size is not an integer')
  end
end
