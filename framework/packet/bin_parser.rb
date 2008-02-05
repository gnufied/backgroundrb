class BinParser
  def initialize
    @size = 0
    @data = []
    # 0 => reading length
    # 1 => reading actual data
    @parser_state = 0
    @length_string = ""
    @numeric_length = 0
  end

  def extract new_data, &block
    extracter_block = block
    if @parser_state == 0
      length_to_read =  9 - @length_string.length
      len_str,remaining = new_data.unpack("a#{length_to_read}a*")
      if len_str.length < length_to_read
        @length_string << len_str
        return
      else
        @length_string << len_str
        @numeric_length = @length_string.to_i
        @parser_state = 1
        if remaining.length < @numeric_length
          @data << remaining
          @numeric_length = @numeric_length - remaining.length
        elsif remaining.length == @numeric_length
          @data << remaining
          extracter_block.call(@data.join)
          @data = []
          @parser_state = 0
          @length_string = ""
          @numeric_length = 0
        else
          pack_data,remaining = remaining.unpack("a#{@numeric_length}a*")
          @data << pack_data
          extracter_block.call(@data.join)
          @data = []
          @parser_state = 0
          @length_string = ""
          @numeric_length = 0
          extract(remaining,&extracter_block)
        end
      end
    elsif @parser_state == 1
      pack_data,remaining = new_data.unpack("a#{@numeric_length}a*")
      if pack_data.length < @numeric_length
        @data << pack_data
        @numeric_length = @numeric_length - pack_data.length
      elsif pack_data.length == @numeric_length
        @data << pack_data
        extracter_block.call(@data.join)
        @data = []
        @parser_state = 0
        @length_string = ""
        @numeric_length = 0
      else
        @data << pack_data
        extracter_block.call(@data.join)
        @data = []
        @parser_state = 0
        @length_string = ""
        @numeric_length = 0
        extract(remaining,&extracter_block)
      end
    end
  end
end

