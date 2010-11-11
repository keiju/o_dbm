
require "rubygems"

Gem::Specification.new do |s|
  s.name = "o_dbm"
  s.authors = "Keiju.Ishitsuka"
  s.email = "keiju@ishitsuka.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "Object Base dbm"
  s.rubyforge_project = s.name
  s.homepage = "http://github.com/keiju/o_dbm"
  s.version = `git tag`.split.collect{|e| e.scan(/v([0-9]+)\.([0-9]+)(?:\.([0-9]+))?/)}.flatten(1).collect{|v| [v[0].to_i, v[1].to_i, v[2].nil? ? -1 : v[2].to_i]}.sort.last.join(".")
  s.require_path = "."
#  s.test_file = ""
#  s.executable = ""
  s.files = [
	"o_dbm.rb", 
	"o_dbm.gemspec",
	*Dir.glob(" doc/*.{rd,html}")]
  s.description = <<EOF
Object Base dbm.
EOF
end

# Editor settings
# - Emacs -
# local variables:
# mode: Ruby
# end:
