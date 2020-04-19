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

require_relative "email"

module Lazylead
  #
  # A postman to send emails.
  #
  # Author:: Yurii Dubinka (yurii.dubinka@gmail.com)
  # Copyright:: Copyright (c) 2019-2020 Yurii Dubinka
  # License:: MIT
  class Postman
    # Send an email.
    # :to     :: the 'to' email addresses.
    # :mail   :: the mail configuration, like from, cc, subject, template.
    # :binds  :: the template bind variables.
    def send(to, mail, binds)
      html = make_body(mail, binds)
      also = make_cc(mail)
      Mail.deliver do
        to to
        from mail["from"]
        cc also if mail.key? "cc"
        subject mail["subject"]
        html_part do
          content_type "text/html; charset=UTF-8"
          body html
        end
      end
    end

    private

    # Construct html document from template and binds.
    def make_body(mail, binds)
      Email.new(
        mail["template"],
        binds.merge(version: Lazylead::VERSION)
      ).render
    end

    # Detect "cc" email addresses.
    # Split "cc" emails to array if "cc" has ',' symbol.
    def make_cc(mail)
      mail["cc"].split(",").map(&:strip).reject(&:empty?) if mail.key? "cc"
    end
  end
end
