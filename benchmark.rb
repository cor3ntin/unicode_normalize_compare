require 'bundler/setup'

unicode_gem_avail = false
begin
  require 'unicode'
  unicode_gem_avail = true
  # Keep `Unicode` class from here from getting in way of ActiveSupports `Unicode` class, gah!
  UnicodeGem = Unicode
  Unicode = nil
rescue LoadError 
  nil
end

require 'active_support/multibyte/unicode'
require 'unicode_utils'
require 'twitter_cldr'
require 'unf'

# Hash of lambdas taking |str, form|, where
# form should be symbol :nfc, :nfkc, :nfd, or :nfkd

normalizations = {}

normalizations[:activesupport] = lambda do |str, form|
  # activesupport wants just :c, :kc, :d, or :kd
  form = form.to_s.slice(2, form.length).to_sym
  ActiveSupport::Multibyte::Unicode.normalize(str, form)
end

normalizations[:unicode_utils] = lambda do |str, form|
  # eg UnicodeUtils.nfc(str)
  case form
  when :nfc
    UnicodeUtils.nfc(str)
  when :nfkc
    UnicodeUtils.nfkc(str)
  when :nfd
    UnicodeUtils.nfd(str)
  when :nfkd
    UnicodeUtils.nfkd(str)
  else
    raise ArgumentError
  end
end

normalizations[:twitter_cldr] = lambda do |str, form|
  # eg TwitterCldr::Normalization::NFD.normalize("français") 
  case form
  when :nfc
    TwitterCldr::Normalization.normalize(str, using: :nfc)
  when :nfkc
    TwitterCldr::Normalization.normalize(str, using: :nfkc)
  when :nfd
    TwitterCldr::Normalization.normalize(str, using: :nfd)
  when :nfkd
    TwitterCldr::Normalization.normalize(str, using: :nfkd)
  else
    raise ArgumentError
  end
end

normalizations[:unf] = lambda do |str, form|
  UNF::Normalizer.normalize(str, form)
end

if unicode_gem_avail 
  normalizations[:unicode] = lambda do |str, form|
    case form
    when :nfc
      UnicodeGem::nfc(str)
    when :nfkc
      UnicodeGem::nfkc(str)
    when :nfd
      UnicodeGem::nfd(str)
    when :nfkd
      UnicodeGem::nfkd(str)
    else
      raise ArgumentError
    end
  end
end

alternatives = [:unicode_utils, :activesupport, :twitter_cldr, :unf]
alternatives.push :unicode if unicode_gem_avail


require 'benchmark'

iterations = 30

test_data_array = File.open(File.expand_path("../test_utf8.txt", __FILE__), "r:UTF-8").readlines

Benchmark.bmbm do |x|
  alternatives.each do |alt|
    x.report(alt.to_s + " " + Gem.loaded_specs[alt.to_s].version.to_s) do
      iterations.times do
        test_data_array.each do |line|
          str = normalizations[alt].call(line, :nfc)
          str = normalizations[alt].call(str, :nfd)

          normalizations[alt].call(str, :nfkc)
          normalizations[alt].call(line, :nfkd)
        end
      end
    end
  end
end
