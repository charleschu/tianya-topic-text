#encoding: utf-8
require 'debugger'
require 'nokogiri'
require 'open-uri'
time_start = Time.now
#url = "http://bbs.tianya.cn/post-develop-1868959-1.shtml"

class Topic
  attr_accessor :content_boxes, :author_id, :text, :pages
  REPLY_REGEX = /^(\r\n\t\t\t\t\t\t\t\u3000\u3000)@(.+\s(\d+)\u697C.+)/
  CONTENT_BOX_SELECTOR = 'div.atl-item'
  TEXT_BOX_SELECTOR = 'div.bbs-content'

  def initialize(first_page_url, last_page_no)
    raise "请输入网址" unless first_page_url
    @first_page_url = first_page_url
    @last_page_no = last_page_no
    set_pages
    set_content_boxes
    set_author_id
    set_content_text
  end

  def set_pages
    @pages ||= []
    (1..@last_page_no).each do |no|
      url = @first_page_url.gsub(/(\d{1,})\.shtml$/,"#{no}.shtml")
      page = Page.new url
      puts "=======set page #{no} success"
      @pages << page
    end
  end

  def set_content_boxes
    @content_boxes ||= []
    pages.each{|page| @content_boxes.concat page.content_boxes}
  end

  def set_author_id
    first_content_box = ContentBox.new(content_boxes.first)
    @author_id = first_content_box.get_author_id
  end

  def set_content_text
    @text ||= ''
    pages.each{|page| @text += page.text}
    @text
  end

  def title
    @title ||= pages.first.title.gsub(/\s+/, "-")
  end

  def write_to_file
    File.open("#{title}.txt", 'a'){|f|f.write(text)}
  end

  class Page
    attr_accessor :url, :content_boxes, :author_id, :text, :html

    def initialize(url)
      @url = url
      set_content_boxes
      set_content_text
    end

    def set_content_boxes
      begin
        doc = open(url)
      rescue OpenURI::HTTPError => e
        server_error = Topic::ServerError.new e
        puts server_error.message
        raise server_error
      end
      @html = Nokogiri::HTML doc
      @content_boxes = html.css('div.atl-item')
    end

    def set_content_text
      @text = ''
      content_boxes.each_with_index do |content_box, index|
        content_box = Topic::ContentBox.new(content_box)
        if content_box.get_author_id == author_id
          box_text = content_box.text
          @text += box_text if !content_box.is_a_reply?
        end
      end
    end

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

    # set a proxy for all of the content_box_object's method
    def method_missing(name, *args, &block)
      @content_box_object.send(name, *args, &block)
    end
  end

  class ServerError < StandardError
    def initialize(open_uri_error_object)
      @message = open_uri_error_object.message
      @message = "请检查网址" if @message == "404 Not Found"
      super(@message)
    end
  end
end
