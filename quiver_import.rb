require 'json'
require 'securerandom'
require 'uri'

# USAGE: ruby quiver_import.rb /folder/containing/md/files/ /export/location.qvnotebook 'Notebook Name'
# - Takes all the .md files in the first argument and puts them in a directory
#   in the second argument (add .qvnotebook to the name for easy importing)
# - Each .md file will be a separate note
# - Images are allowed provided the paths specified are relative to the .md file
#   that references them. TODO: support URL images by just passing the markdown
#   through.

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
    @@LANG_MAP = {
      'bash' => 'sh'
    }

    attr_accessor :blocks, :codeblock, :mdblock, :inside_code
    attr_reader   :input_file, :output_dir, :title, :tags, :has_title_and_tags

    def initialize(input_file, output_dir)
      @blocks         = []
      @codeblock      = CodeBlock.new('')
      @mdblock        = MarkdownBlock.new('')
      @input_file     = input_file
      @output_dir     = output_dir
      @inside_code    = false
      @title, @tags, @has_title_and_tags = Import.parse_title_and_tags(input_file)
    end

    def self.parse_title_and_tags(input_file)
      header      = File.foreach(input_file).first(2)
      title_match = header[0].match(/#\s*(.+)/)
      tag_match   = header[1].match(/(?<=\[)(.+)(?=\])/)
      [
        title_match ? title_match[1] : input_file,
        tag_match   ? tag_match[1].split(/[\s,\|]/).reject(&:empty?) : [],
        !title_match.nil? || !tag_match.nil?
      ]
    end

    def process_code_boundary(boundary_match)
      add_and_reset_blocks
      @inside_code = !boundary_match[:language].nil?
      if inside_code
        @codeblock.language =
          @@LANG_MAP[boundary_match[:language]] || boundary_match[:language]
      end
    end

    def process_code_line(line)
      @codeblock.data = @codeblock.data + line
    end

    def process_md_line(line)
      if line =~ /!\[(?<alt_text>.*)\]\((?<src>\S+)( "(?<title>.*)")?\)/
        line = process_img_line(line)
      end
      @mdblock.data = @mdblock.data + line
    end

    # TODO: cache images and don't recopy them if they already exist in the destination
    def process_img_line(line)
      img_match = line.scan(/!\[(?<alt_text>.*)\]\((?<src>\S+)( "(?<title>.*)")?\)/)

      # Pass http/https directly through (don't bother downloading them)
      # For local files, copy them to /resources and link with quiver-image-url
      img_match
        .reject {|alt_text, src, title| URI::regexp(['http', 'https']) =~ src}
        .each do |alt_text, src, title|
          src_file = File.expand_path(src, File.dirname(@input_file))
          raise "Couldn't find image at: #{src_file}" unless File.exist?(src_file)
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

    def run(title_and_tags = false)
      iter = @has_title_and_tags ? File.foreach(@input_file).drop(2) : File.foreach(@input_file)
      iter.each do |line|
        if (code_boundary = line.match(/```(?<language>\S+)?/))
          process_code_boundary(code_boundary)
        elsif @inside_code
          process_code_line(line)
        else
          process_md_line(line)
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
input_dir, output_dir, notebook_name = ARGV

Dir.glob("#{input_dir}/*.md").each do |note|
  note_output_dir = "#{output_dir}/#{SecureRandom.uuid.upcase}.qvnote"
  Import.new(note, note_output_dir).run
end

notebook_json = {
  name: "#{notebook_name}",
  uuid: SecureRandom.uuid.upcase
}.to_json

IO.write("#{output_dir}/meta.json", notebook_json)
