module BackgrounDRb
  class CronTrigger

    attr_reader :sec, :min, :hour, :day, :month, :wday, :year, :cron_expr

    def initialize(expr)
      self.cron_expr = expr
    end

    def cron_expr=(expr)
      @cron_expr = expr
      self.sec, self.min, self.hour, self.day, self.month, self.wday, self.year = @cron_expr.split(' ')
      # puts inspect
    end

    def fire_time_after(time)
      sec, min, hour, day, month, year, wday, yday, isdst, zone = time.to_a

      loop do
        # year
        unless @year.nil? or @year.include?(year)
          return nil  if year > @year.max
          year = @year.detect do |y| y > year end  # next allowable year
        end

        # month
        unless @month.include?(month)
          # next allowable month
          next_month = @month.detect(lambda { @month.min }) do |m| m > month end
          # reset everything lower
          day, hour, min, sec = @day.min, @hour.min, @min.min, @sec.min
          # carry case
          if next_month < month
            month = next_month
            year += 1
            retry
          end
          month = next_month
        end

        # according to crontab(5):
        # Note: The day of a command’s execution can be specified by two fields — day of month, and day of week.
        # If both fields are restricted (i.e., aren’t *), the command  will  be  run  when  either
        # field matches the current time.  For example, ‘‘30 4 1,15 * 5’’ would cause a command to be
        # run at 4:30 am on the 1st and 15th of each month, plus every Friday.
        if !day_restricted? and wday_restricted?
          # unrestricted day, restricted wday. go by wday
          unless @wday.include?(wday)
            next_wday = @wday.detect(lambda { @wday.min }) do |w| w > wday end
            hour, min, sec = @hour.min, @min.min, @sec.min
            if next_wday < wday
              # next week.
              day += + 7 - (wday - next_wday)
              if day > month_days(year, month)
                day -= month_days(year, month)
                month += 1
              end
              wday = next_wday              
              retry
            end
            
            day += (next_wday - wday)
            wday = next_wday
          end
        elsif !wday_restricted? and day_restricted?
          # unrestricted wday, restricted day. go by day
          month_days = (1 .. month_days(year, month))
          days = @day.select do |d| month_days === d end
          unless days.include?(day)
            next_day = days.detect(lambda { days.min }) do |d| d > day end
            hour, min, sec = @hour.min, @min.min, @sec.min
            if next_day.nil? or next_day < day
              day = next_day.nil? ? @day.min : next_day
              month += 1
              retry
            end
            day = next_day
          end
        else        
          # both @day and @wday are restricted, or unrestricted
          month_days = (1 .. month_days(year, month))
          days = @day.select do |d| month_days === d end
          unless days.include?(day) || @wday.include?(wday)
            next_day = days.detect(lambda { days.min }) do |d| d > day end
            next_wday = @wday.detect(lambda { @wday.min }) do |w| w > wday end
            hour, min, sec = @hour.min, @min.min, @sec.min
            
            # which is less? next_day or next_wday?
            # just calculate how many days from 'day' they both are.

            if next_day.nil? or next_day < day
              next_by_mday = month_days(year, month) - day + (next_day.nil? ? @day.min : next_day)
            else
              next_by_mday = next_day - day              
            end
            
            if next_wday.nil? or next_wday < wday
              next_by_wday = 7 - wday + (next_wday.nil? ? @day.min : next_wday)
            else
              next_by_wday = next_wday - wday
            end
            
            next_day = [next_by_wday, next_by_mday].min
            if next_day + day > month_days(year, month)
              # next fire lands on next month
              day += next_day - month_days(year, month)
              wday += next_day % 7
              wday -= 7 if wday > 6
              month += 1
              if month > 12
                year += 1
                month = 1
              end
              retry
            end
            day += next_day
          end
        end

        
        
        # hour
        unless @hour.include?(hour)
          next_hour = @hour.detect(lambda { @hour.min }) do |h| h > hour end
          min, sec = @min.min, @sec.min
          if next_hour < hour
            hour = next_hour
            day += 1
            retry
          end
          hour = next_hour
        end

        # min
        unless @min.include?(min)
          next_min = @min.detect(lambda { @min.min }) do |m| m > min end
          sec = @sec.min
          if next_min < min
            min = next_min
            hour += 1
            retry
          end
          min = next_min
        end

        # sec
        unless @sec.include?(sec)
          next_sec = @sec.detect(lambda { @sec.min }) do |s| s > sec end
          if next_sec < sec
            sec = next_sec
            min += 1
            retry
          end
          sec = next_sec
        end

        break
      end

      Time.local sec, min, hour, day, month, year, wday, yday, isdst, zone
    end

    def day_restricted?
      return !@day.eql?(1..31)
    end

    def wday_restricted?
      return !@wday.eql?(0..6)
    end

    # TODO: mimic attr_reader to define all of these
    def sec=(sec)
      @sec = parse_part(sec, 0 .. 59)
    end

    def min=(min)
      @min = parse_part(min, 0 .. 59)
    end

    def hour=(hour)
      @hour = parse_part(hour, 0 .. 23)
    end

    def day=(day)
      @day = parse_part(day, 1 .. 31)
    end

    def month=(month)
      @month = parse_part(month, 1 .. 12)
    end

    def year=(year)
      @year = parse_part(year)
    end

    def wday=(wday)
      @wday = parse_part(wday, 0 .. 6)
    end

    LeapYearMonthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    private
    def month_days(y, m)
      if ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0)
        LeapYearMonthDays[m-1]
      else
        CommonYearMonthDays[m-1]
      end
    end

    # 0-5,8,10; 0-5; *; */5
    def parse_part(part, range=nil)
      return range  if part.nil? or part == '*' or part =~ /^[*0]\/1$/

      r = Array.new
      part.split(',').each do |p|
        if p =~ /-/  # 0-5
          r << Range.new(*p.scan(/\d+/)).to_a.map do |x| x.to_i end
        elsif p =~ /(\*|\d+)\/(\d+)/ and not range.nil?  # */5, 2/10
          min = $1 == '*' ? 0 : $1.to_i
          inc = $2.to_i
          (min .. range.end).each_with_index do |x, i|
            r << x  if i % inc == 0
          end
        else
          r << p.to_i
        end
      end

      r.flatten
    end

  end

end
