using Test
using JBash

@testset "JBash.jl Tests" begin

    @testset "Macro Tests" begin
        # Test @bashwrap
        @test begin
            @bashwrap "echo hello"
            true # if it runs without error
        end

        # Test @bashcap
        @test strip(@bashcap "echo hello") == "hello"

        # Test @bashpipe
        @test begin
            output = @bashpipe "echo hello"
            strip(output) == "hello"
        end
    end

    @testset "Piping Tests" begin
        # Test Julia to Bash piping
        @test begin
            julia_data = "julia says hello"
            bash_cmd = "cat"
            output = julia_to_bash_pipe(julia_data, bash_cmd)
            strip(output) == julia_data
        end

        # Test Bash to Julia piping
        @test begin
            bash_output = @bashcap "echo 42"
            julia_var = parse(Int, strip(bash_output))
            julia_var == 42
        end
    end

    @testset "Conditional and Error Handling Tests" begin
        # Test @bashif
        @test begin
            if @bashif "true"
                true
            else
                false
            end
        end

        @test begin
            if @bashif "false"
                false
            else
                true
            end
        end

        # Test @bashsafe
        @test_throws BashBashExecutionError @bashsafe "false"
        @test strip(@bashsafe "echo success") == "success"
    end

end
