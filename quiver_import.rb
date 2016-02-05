require 'pry'
require 'json'
require 'securerandom'


class CodeBlock
  attr_accessor :language, :data

  def initialize(data, language = 'text')
    @language = language
    @data     = data
  end

  def to_json(*a)
    { type: 'code', language: language, data: data }.to_json(*a)
  end
end

class MarkdownBlock
  attr_accessor :data

  def initialize(data)
    @data = data
  end

  def to_json(*a)
    { type: 'markdown', data: data }.to_json(*a)
  end
end

module QuiverImport
  class Import
    attr_accessor :blocks, :codeblock, :mdblock
    attr_reader   :input_file, :output_dir, :title

    def initialize(input_file, output_dir)
      @blocks       = []
      @codeblock    = CodeBlock.new('')
      @mdblock      = MarkdownBlock.new('')
      @input_file   = input_file
      @output_dir   = output_dir
      @title, @tags = Import.parse_title_and_tags(input_file)
    end

    def self.parse_title_and_tags(input_file)
      header      = File.foreach(input_file).first(2)
      title_match = header[0].match(/#\s*(.+)/)
      tag_match   = header[1].match(/(?<=\[)(.+)(?=\])/)
      [
        title_match.nil? ? input_file : title_match[1],
        tag_match.nil?   ? [] : tag_match[1].split(/[\s,\|]/).reject(&:empty?)
      ]
    end

    def run(strip_toc = true, reduce_headers = true)
      inside_code = false

      File.foreach(@input_file).drop(2).each do |line|
        if (code_boundary = line.match(/```(?<language>\S+)?/))
          add_and_reset_blocks
          if code_boundary[:language]
            inside_code = true
            @codeblock.language = code_boundary[:language]
          else
            inside_code = false
          end
        else
          if inside_code
            @codeblock.data = @codeblock.data + line
          else
            next if strip_toc && line =~ /\[TOC\]/
            line = line[1..-1] if reduce_headers and line =~ /\#{2,}/
            @mdblock.data = @mdblock.data + line
          end
        end
      end

      add_and_reset_blocks
      clean_blocks

      IO.write("#{@output_dir}/content.json", content_json)
      IO.write("#{@output_dir}/meta.json", meta_json)
    end
  end


  private
  def clean_blocks
    @blocks.each_with_index do |block, idx|
      block.data = block.data.strip
      blocks.slice!(idx) if block.data.empty?
    end
  end

  def add_and_reset_blocks
    [@codeblock, @mdblock].each do |block|
      @blocks.push block unless block.data.empty?
    end

    @codeblock = CodeBlock.new('')
    @mdblock   = MarkdownBlock.new('')
  end

  def content_json(*a)
    {
      'title': (@title || @input_file),
      'cells': @blocks
    }.to_json(*a)
  end

  def meta_json
    now = Time.now.utc.to_i
    {
      'created_at': now,
      'tags': @tags,
      'title': @title,
      'updated_at': now,
      'uuid': SecureRandom.uuid
    }.to_json
  end
end

include QuiverImport
input_file = ARGV[0]
output_dir = ARGV[1]

Import.new(input_file, output_dir).run
