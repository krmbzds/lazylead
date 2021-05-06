# frozen_string_literal: true

# The MIT License
#
# Copyright (c) 2019-2021 Yurii Dubinka
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom
# the Software is  furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.

require "tmpdir"
require "nokogiri"
require "active_support/core_ext/hash/conversions"
require_relative "../../os"
require_relative "../../salt"
require_relative "../../opts"

module Lazylead
  module Task
    module Svn
      #
      # Detect particular text in diff commit.
      #
      class Grep
        def initialize(log = Log.new)
          @log = log
        end

        def run(_, postman, opts)
          text = opts.slice("text", ",")
          commits = svn_log(opts).select { |c| c.includes? text }
          postman.send(opts.merge(entries: commits)) unless commits.empty?
        end

        # Return all svn commits for particular date range in repo
        def svn_log(opts)
          cmd = [
            "svn log --diff --no-auth-cache",
            "--username #{opts.decrypt('svn_user', 'svn_salt')}",
            "--password #{opts.decrypt('svn_password', 'svn_salt')}",
            "-r {#{from(opts)}}:{#{now(opts)}} #{opts['svn_url']}"
          ]
          stdout = OS.new.run cmd.join(" ")
          stdout.split("-" * 72).reject(&:blank?).reverse.map { |e| Entry.new(e) }
        end

        # The start date & time for search range
        def from(opts)
          (now(opts).to_time - opts["period"].to_i).to_datetime
        end

        # The current date & time for search range
        def now(opts)
          if opts.key? "now"
            DateTime.parse(opts["now"])
          else
            DateTime.now
          end
        end
      end
    end
  end

  # Single SVN commit details
  class Entry
    def initialize(commit)
      @commit = commit
    end

    def to_s
      "#{rev} #{msg}"
    end

    def rev
      header.first[1..]
    end

    def author
      header[1]
    end

    def time
      header[2]
    end

    def msg
      lines[1]
    end

    # The modified lines contains expected text
    def includes?(text)
      text = [text] unless text.respond_to? :each
      lines[4..].select { |l| l.start_with? "+" }
                .any? { |l| text.any? { |t| l.include? t } }
    end

    def lines
      @lines ||= @commit.split("\n").reject(&:blank?)
    end

    def header
      @header ||= lines.first.split(" | ").reject(&:blank?)
    end

    # Detect SVN diff lines with particular text
    def diff(text)
      @diff ||= begin
        files = affected(text).uniq
        @commit.split("Index: ")
               .select { |i| files.any? { |f| i.start_with? f } }
               .map { |i| i.split "\n" }
               .flatten
      end
    end

    # Detect affected files with particular text
    def affected(text)
      occurrences = lines.each_index.select do |i|
        lines[i].start_with?("+") && text.any? { |t| lines[i].include? t }
      end
      occurrences.map do |occ|
        lines[2..occ].reverse.find { |l| l.start_with? "Index: " }[7..]
      end
    end
  end
end
