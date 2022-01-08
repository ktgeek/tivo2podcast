# frozen_string_literal: true

require "irb"
require "irb/completion"

# The code to invoke IRB as a console came from
# http://jasonroelofs.com/2009/04/02/embedding-irb-into-your-ruby-application/
module IRB # :nodoc:
  def self.start_session(the_binding)
    unless @__initialized
      args = ARGV
      ARGV.replace([])
      IRB.setup(nil)
      ARGV.replace(args)
      @__initialized = true
    end

    @CONF[:IRB_NAME] = "TiVo2Podcast"

    workspace = WorkSpace.new(the_binding)

    irb = Irb.new(workspace)

    @CONF[:IRB_RC]&.call(irb.context)
    @CONF[:MAIN_CONTEXT] = irb.context

    catch(:IRB_EXIT) do
      irb.eval_input
    end
  end
end
