# frozen_string_literal: true

# The MIT License
#
# Copyright (c) 2019-2020 Yurii Dubinka
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

require "backtrace"
require "require_all"
require "forwardable"
require "active_record"
require_rel "task"
require_rel "system"
require_relative "cc"
require_relative "log"
require_relative "postman"
require_relative "exchange"

#
# ORM domain model entities.
#
# Author:: Yurii Dubinka (yurii.dubinka@gmail.com)
# Copyright:: Copyright (c) 2019-2020 Yurii Dubinka
# License:: MIT
module Lazylead
  # ORM-related methods
  module ORM
    # Tables from database may have configuration in json column.
    # Some of those properties might be configured/overridden by environment
    # variable using macros "${...}"
    #   {
    #      ...
    #      "user" = "${my_user}",
    #      "pass" = "${my_pass}"
    #      "url" = "https://url.com"
    #      ...
    #   }
    # next, we need to configure following environment variables(ENV)
    #   my_user=XXXXX
    #   my_pass=YYYYY
    # thus, the result of this method is
    #   {
    #      ...
    #      "user" = "XXXXXX",
    #      "pass" = "YYYYYY"
    #      "url" = "https://url.com"
    #      ...
    #   }
    def env(opts)
      opts.each_with_object({}) do |e, o|
        k = e[0]
        v = e[1]
        if v.respond_to? :start_with?
          v = ENV[v.slice(2, v.length - 3)] if v.start_with? "${"
        end
        o[k] = v
      end
    end

    # Convert json-based database column 'properties' to hash.
    def to_hash
      JSON.parse(properties).to_h
    end

    def to_s
      attributes.map { |k, v| "#{k}='#{v}'" }.join(", ")
    end

    def inspect
      to_s
    end

    # General lazylead task.
    class Task < ActiveRecord::Base
      include ORM
      belongs_to :team, foreign_key: "team_id"
      belongs_to :system, foreign_key: "system"

      def exec(log = Log::NOTHING)
        sys = system.connect(log)
        opts = props
        opts = detect_cc(sys) if opts.key? "cc"
        action.constantize.new(log).run(sys, postman(log), opts)
      end

      def detect_cc(sys)
        opts = props
        opts["cc"] = CC.new.detect(opts["cc"], sys)
        return opts.except "cc" if opts["cc"].is_a? EmptyCC
        opts
      end

      def props
        @props ||= begin
                     if team.nil?
                       env(to_hash)
                     else
                       env(team.to_hash.merge(to_hash))
                     end
                   end
      end

      def postman(log = Log::NOTHING)
        if props.key? "postman"
          props["postman"].constantize.new(log)
        else
          Postman.new
        end
      end
    end

    # A task with extended logging
    # @see Lazylead::ORM::Task
    class VerboseTask
      extend Forwardable
      def_delegators :@orig, :id, :name, :team, :to_s, :inspect, :props

      def initialize(orig, log = Log::NOTHING)
        @orig = orig
        @log = log
      end

      def exec
        Logging.mdc["tid"] = "task #{id}"
        @log.debug "'#{name}' is started."
        @log.warn "No postman, stub is used." unless props.key? "postman"
        @log.warn "No team." if team.nil?
        @orig.exec @log
        @log.debug "'#{name}' is completed"
      rescue StandardError => e
        msg = <<~MSG
          ll-006: Task ##{id} #{e} (#{e.class}) at #{self}
          #{Backtrace.new(e) if ARGV.include? '--trace'}"
        MSG
        @log.error msg
      ensure
        Logging.mdc["tid"] = ""
      end
    end

    # Ticketing systems to monitor.
    class System < ActiveRecord::Base
      include ORM

      # Make an instance of ticketing system for future interaction.
      def connect(log = Log::NOTHING)
        opts = to_hash
        if opts["type"].empty?
          log.warn "No task system details provided, an empty stub is used."
          Empty.new
        else
          opts["type"].constantize.new(
            env(opts.except("type", "salt")),
            opts["salt"].blank? ? NoSalt.new : Salt.new(opts["salt"]),
            log
          )
        end
      end
    end

    # A team for lazylead task.
    # Each team may have several tasks.
    class Team < ActiveRecord::Base
      include ORM
    end
  end
end
