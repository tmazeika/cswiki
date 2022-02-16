# frozen_string_literal: true

require 'asciidoctor'
require 'fileutils'
require 'liquid'

def base_url
  ENV['BASE_URL'] || ''
end

Liquid::Template.error_mode = :strict

class Template
  def initialize(name)
    @name = name
    raise "Template '#{name}' not found" unless File.exist? filename
  end

  def filename
    "src/#{@name}.liquid"
  end

  def render(*args)
    parse.render! Hash[*args].merge(
      'base_url' => base_url
    )
  end

  private

  def parse
    Liquid::Template.parse File.read(filename)
  end
end

class Article
  def initialize(filename)
    @filename = filename
  end

  def slug
    File.basename @filename, '.*'
  end

  def title
    doc.doctitle
  end

  def url
    "#{base_url}/wiki/#{slug}.html"
  end

  def body
    Asciidoctor.convert_file @filename, safe: :safe, to_file: false, attributes: {
      'source-highlighter' => 'rouge',
      'rouge-style' => 'github'
    }
  end

  def to_h
    { 'title' => title, 'url' => url }
  end

  private

  def doc
    @doc ||= Asciidoctor.load_file @filename, safe: :safe, header_only: true
  end
end

FileUtils.rm_rf 'build'
FileUtils.mkdir 'build'
FileUtils.mkdir 'build/wiki'
FileUtils.cp_r 'src/public/.', 'build'

default_layout = Template.new 'layouts/default'
article_view = Template.new 'views/article'
index_view = Template.new 'views/index'

articles = Dir['content/**/*.adoc'].map { |filename| Article.new filename }

articles.each do |article|
  File.write "build/wiki/#{article.slug}.html", default_layout.render(
    'page' => {
      'title' => "#{article.title} - CSWiki"
    },
    'content' => article_view.render(
      article.to_h.merge(
        'body' => article.body
      )
    )
  )
end

File.write 'build/index.html', default_layout.render(
  'page' => {
    'title' => 'CSWiki'
  },
  'content' => index_view.render(
    'articles' => articles.map(&:to_h)
  )
)
