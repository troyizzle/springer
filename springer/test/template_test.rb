require "minitest/autorun"

class TemplateTest < Minitest::Test
  def setup
    system("[ -d test_app ] && rm -rf test_app")
  end

  def teardown
    setup
  end

  def test_generator_succeeds
    output, _err = capture_subprocess_io do
      system("SKIP_GIT=1 rails new -m template.rb test_app")
    end

    assert_includes output, "App successfully created!"
  end
end
