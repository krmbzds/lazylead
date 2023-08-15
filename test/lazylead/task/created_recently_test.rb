# frozen_string_literal: true

# The MIT License
#
# Copyright (c) 2019-2022 Yurii Dubinka
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

require_relative "../../test"
require_relative "../../../lib/lazylead/log"
require_relative "../../../lib/lazylead/smtp"
require_relative "../../../lib/lazylead/postman"
require_relative "../../../lib/lazylead/schedule"
require_relative "../../../lib/lazylead/model"
require_relative "../../../lib/lazylead/cli/app"
require_relative "../../../lib/lazylead/system/jira"
require_relative "../../../lib/lazylead/task/alert/alert"

module Lazylead
  class CreatedRecentlyTest < Lazylead::Test
    test "issues were fetched" do
      Smtp.new.enable
      Task::Alert.new.run(
        NoAuthJira.new("https://jira.mongodb.org"),
        Postman.new,
        Opts.new(
          "from" => "fake@email.com",
          "to" => "my@team.com",
          "sql" => "key in (JAVA-4403, JAVA-4417)",
          "subject" => "[CR] 20min ago!",
          "template" => "lib/messages/created_recently.erb"
        )
      )

      assert_email "[CR] 20min ago!",
                   "JAVA-4403", "JAVA-4417"
    end
  end
end
