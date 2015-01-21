#encoding: utf-8
require 'debugger'
require 'nokogiri'
require 'open-uri'
time_start = Time.now
#url = "http://bbs.tianya.cn/post-develop-1868959-1.shtml"

class Topic
  attr_accessor :url, :content_boxes, :author_id, :text
  REPLY_REGEX = /^(\r\n\t\t\t\t\t\t\t\u3000\u3000)@(.+\s(\d+)\u697C.+)/
  CONTENT_BOX_SELECTOR = 'div.atl-item'
  TEXT_BOX_SELECTOR = 'div.bbs-content'

  def initialize(url)
    raise "you should add the url" unless url
    @url = url
    set_content_boxes
    set_author_id
    set_content_text
  end

  def set_content_boxes
    doc = Nokogiri::HTML(open(url))
    @content_boxes = doc.css('div.atl-item')
  end

  def set_author_id
    first_content_box = ContentBox.new(content_boxes.first)
    @author_id = first_content_box.get_author_id
  end

  def set_content_text
    @text = ''
    content_boxes.each_with_index do |content_box, index|
      content_box = ContentBox.new(content_box)
      if content_box.get_author_id == author_id
        box_text = content_box.text
        @text += box_text if !content_box.is_a_reply?
      end
    end
  end

  def write_to_file(file_path)
    File.open('file_path', w){|f|f.write(text)}
  end

  class ContentBox
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

    def initialize(content_box_object)
      @content_box_object = content_box_object
    end

    def get_author_id
      @content_box_object['_host']
    end

    def is_a_reply?
      !!(text =~ Topic::REPLY_REGEX)
    end

    def text
      @content_box_object.css(Topic::TEXT_BOX_SELECTOR).text
    end

    def method_missing(name, *args, &block)
      @content_box_object.send(name, *args, &block)
    end
  end
end
