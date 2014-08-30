###
# Compass
###

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

# Reload the browser automatically whenever files change
# configure :development do
#   activate :livereload
# end

# Methods defined in the helpers block are available in templates
# helpers do
#   def some_helper
#     "Helping"
#   end
# end

# page '/text/*.html', layout: :text_tag
page '/text/*/*', layout: :text_item

set :css_dir, '/css'

set :js_dir, '/js'

set :images_dir, '/img'

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  # activate :relative_assets

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true

Time.zone = 'Tokyo'

activate :blog do |blog|
  blog.prefix = 'text'
  blog.sources = '{year}/{month}{day}-{title}.html'
  blog.permalink = '{year}/{month}{day}-{title}.html'
  blog.default_extension = '.md'
  blog.taglink = '{tag}.html'
  blog.tag_template = 'text/tag.html'
end

page '/text/atom.xml', layout: false
page 'CNAME', layout: false

{
  author: 'daimatz',
  site_name: 'daimatz.net',
  site_url: 'http://daimatz.net',
  time_format: '%Y-%m-%d',
  twitter: 'daimatz',
  github: 'daimatz',
  facebook: 'daimatz',
}.each do |k, v|
  set k, v
end

class Redcarpet::Render::HTML
  def preprocess(text)
    text.gsub(/([^\x01-\x7E])\n([^\x01-\x7E])/, '\1\2')
  end
end

activate :syntax, line_numbers: true
activate :livereload
