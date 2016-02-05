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
    attr_accessor :blocks, :codeblock, :mdblock, :inside_code
    attr_reader   :input_file, :output_dir, :title

    def initialize(input_file, output_dir)
      @blocks       = []
      @codeblock    = CodeBlock.new('')
      @mdblock      = MarkdownBlock.new('')
      @input_file   = input_file
      @output_dir   = output_dir
      @title, @tags = Import.parse_title_and_tags(input_file)
      @inside_code  = false
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

    def process_code_boundary(boundary_match)
      add_and_reset_blocks
      @inside_code = !boundary_match[:language].nil?
      @codeblock.language = boundary_match[:language] if inside_code
    end

    def process_code_line(line)
      @codeblock.data = @codeblock.data + line
    end

    def process_md_line(line, strip_toc, reduce_headers)
      return if strip_toc && line =~ /\[TOC\]/                  # Ignore TOC
      line = line[1..-1] if reduce_headers and line =~ /\#{2,}/ # Remove one level from every header
      if line =~ /!\[(?<alt_text>.*)\]\((?<src>\S+)( "(?<title>.*)")?\)/
        line = process_img_line(line)
      end
      @mdblock.data = @mdblock.data + line
    end

    # TODO: cache images and don't recopy them if they already exist in the destination
    def process_img_line(line)
      img_match = line.scan(/!\[(?<alt_text>.*)\]\((?<src>\S+)( "(?<title>.*)")?\)/)
      img_match.each do |alt_text, src, title|
        src_file = File.expand_path(src, File.dirname(@input_file))
        raise "Couldn't find image at: #{src_file}" if !File.exist?(src_file)
        dest = img_to_resources(src_file)
        line.sub!(src, dest)
      end
      line
    end

    def img_to_resources(src)
      system 'mkdir', '-p', "#{@output_dir}/resources"
      src_extension = File.extname(src)
      dest_filename = "#{SecureRandom.uuid.upcase}#{src_extension}"
      system 'cp', "#{src}", "#{@output_dir}/resources/#{dest_filename}"
      "quiver-image-url/#{dest_filename}"
    end

    def run(strip_toc = true, reduce_headers = true)
      File.foreach(@input_file).drop(2).each do |line|
        if (code_boundary = line.match(/```(?<language>\S+)?/))
          process_code_boundary(code_boundary)
        elsif @inside_code
          process_code_line(line)
        else
          process_md_line(line, strip_toc, reduce_headers)
        end
      end

      add_and_reset_blocks
      clean_blocks

      system 'mkdir', '-p', "#{@output_dir}"
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
      title: (@title || @input_file),
      cells: @blocks
    }.to_json(*a)
  end

  def meta_json
    now = Time.now.utc.to_i
    {
      created_at: now,
      tags: @tags,
      title: @title,
      updated_at: now,
      uuid: SecureRandom.uuid.upcase
    }.to_json
  end
end

include QuiverImport
input_file = ARGV[0]
output_dir = ARGV[1]

Import.new(input_file, output_dir).run
