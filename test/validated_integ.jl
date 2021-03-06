# Tests for validated_integ

using TaylorModels
# using LinearAlgebra: norm
using Test
# using Random

const _num_tests = 1_000

setformat(:full)

# NOTE: IntervalArithmetic v0.16.0 includes this function; but
# IntervalRootFinding is bounded to use v0.15.x
interval_rand(X::Interval{T}) where {T} = X.lo + rand(T) * (X.hi - X.lo)
interval_rand(X::IntervalBox) = interval_rand.(X)

function test_integ(fexact, t0, qTM, q0, δq0)
    normalized_box = symmetric_box(length(q0), Float64)
    # Time domain
    domt = domain(qTM[1])
    # Random time (within time domain) and random initial condition
    δt = rand(domt)
    δtI = (δt .. δt) ∩ domt
    q0ξ = interval_rand(δq0)
    q0ξB = IntervalBox([(q0ξ[i] .. q0ξ[i]) ∩ δq0[i] for i in eachindex(q0ξ)])
    # Box computed to overapproximate the solution at time δt
    q = evaluate.(evaluate.(qTM, δtI), (normalized_box,))
    # Box computed from the exact solution must be within q
    bb = all(fexact(t0+δtI, q0 .+ q0ξB) .⊆ q)
    # Display details if bb is false
    bb || @show(t0, domt, remainder.(qTM), 
            δt, δtI, q0ξ, q0ξB, q,
            fexact(t0+δtI, q0 .+ q0ξB))
    return bb
end


@testset "Tests for `validated_integ`" begin
    @testset "falling_ball!" begin
        @taylorize function falling_ball!(dx, x, p, t)
            dx[1] = x[2]
            dx[2] = -one(x[1])
            nothing
        end
        exactsol(t, t0, x0) = (x0[1] + x0[2]*(t-t0) - 0.5*(t-t0)^2, x0[2] - (t-t0))

        # Initial conditions
        tini, tend = 0.0, 10.0
        normalized_box = symmetric_box(2, Float64)
        q0 = [10.0, 0.0]
        δq0 = 0.25 * normalized_box
        X0 = IntervalBox(q0 .+ δq0)

        # Parameters
        abstol = 1e-20
        orderQ = 2
        orderT = 4
        ξ = set_variables("ξₓ ξᵥ", order=2*orderQ, numvars=length(q0))

        @testset "Forward integration 1" begin
            tTM, qv, qTM = validated_integ(falling_ball!, X0, tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            end_idx = lastindex(tTM)
            # Random.seed!(1)
            for it = 1:_num_tests
                n = rand(2:end_idx)
                @test test_integ((t,x)->exactsol(t,tini,x), tTM[n], qTM[:,n], q0, δq0)
            end

            tTMf, qvf, qTMf = validated_integ(falling_ball!, X0, tini, tend, orderQ, orderT, abstol,
                adaptive=false)
            @test length(qvf) == length(qv)
            @test qTM == qTMf

            # initializaton with a Taylor model
            X0tm = qTM[:, 1]
            tTM2, qv2, qTM2 = validated_integ(falling_ball!, X0tm, tini, tend, orderQ, orderT, abstol)
            @test qTM == qTM2
        end

        @testset "Forward integration 2" begin
            tTM, qv, qTM = validated_integ2(falling_ball!, X0,
                tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            # Random.seed!(1)
            end_idx = lastindex(tTM)
            for it = 1:_num_tests
                n = rand(2:end_idx)
                @test test_integ((t,x)->exactsol(t,tini,x), tTM[n], qTM[:,n], q0, δq0)
            end

            # initializaton with a Taylor model
            X0tm = qTM[:, 1]
            tTM2, qv2, qTM2 = validated_integ2(falling_ball!, X0tm, tini, tend, orderQ, orderT, abstol)
            @test qTM == qTM2
        end

        # Initial conditions
        tini, tend = 10.0, 0.0
        q0 = [10.0, 0.0]
        δq0 = IntervalBox(-0.25 .. 0.25, 2)
        X0 = IntervalBox(q0 .+ δq0)

        @testset "Backward integration 1" begin
            tTM, qv, qTM = validated_integ(falling_ball!, X0, tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            # Random.seed!(1)
            end_idx = lastindex(tTM)
            for it = 1:_num_tests
                n = rand(2:end_idx)
                @test test_integ((t,x)->exactsol(t,tini,x), tTM[n], qTM[:,n], q0, δq0)
            end

            tTMf, qvf, qTMf = validated_integ(falling_ball!, X0, tini, tend, orderQ, orderT, abstol,
                adaptive=false)
            @test length(qvf) == length(qv)
            @test all(qTM .== qTMf)

            # initializaton with a Taylor model
            X0tm = qTM[:, 1]
            tTM2, qv2, qTM2 = validated_integ(falling_ball!, X0tm, tini, tend, orderQ, orderT, abstol)
            @test qTM == qTM2

            tTM2f, qv2f, qTM2f = validated_integ(falling_ball!, X0tm, tini, tend, orderQ, orderT, abstol,
                adaptive=false)
            @test length(qv2f) == length(qv2)
            @test all(qTM .== qTM2f)
        end

        @testset "Backward integration 2" begin
            tTM, qv, qTM = validated_integ2(falling_ball!, X0,
            tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            # Random.seed!(1)
            end_idx = lastindex(tTM)
            for it = 1:_num_tests
                n = rand(2:end_idx)
                @test test_integ((t,x)->exactsol(t,tini,x), tTM[n], qTM[:,n], q0, δq0)
            end
        end
    end

    @testset "x_square!" begin
        @taylorize function x_square!(dx, x, p, t)
            dx[1] = x[1]^2
            nothing
        end

        exactsol(t, x0) = 1 / (1/x0[1] - t)

        tini, tend = 0., 0.45
        normalized_box = symmetric_box(1, Float64)
        abstol = 1e-15
        orderQ = 5
        orderT = 20
        q0 = [2.]
        δq0 = 0.0625 * normalized_box
        X0 = IntervalBox(q0 .+ δq0)
        ξ = set_variables("ξₓ", numvars=1, order=2*orderQ)

        @testset "Forward integration 1" begin
            tTM, qv, qTM = validated_integ(x_square!, X0, tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            # Random.seed!(1)
            end_idx = lastindex(tTM)
            for it = 1:_num_tests
                n = rand(1:end_idx)
                @test test_integ((t,x)->exactsol(t,x), tTM[n], qTM[:,n], q0, δq0)
            end

            tTMf, qvf, qTMf = validated_integ(x_square!, X0, tini, tend, orderQ, orderT, abstol,
                adaptive=false)
            @test length(qvf) == length(qv)
            @test all(qTMf .== qTM)

            # initializaton with a Taylor model
            X0tm = copy(qTM[:, 1])
            tTM2, qv2, qTM2 = validated_integ(x_square!, X0tm, tini, tend, orderQ, orderT, abstol)
            @test qTM == qTM2
        end

        @testset "Forward integration 2" begin
            tTM, qv, qTM = validated_integ2(x_square!, X0, tini, tend, orderQ, orderT, abstol)

            @test length(qv) == length(qTM[1, :]) == length(tTM)

            # Random.seed!(1)
            end_idx = lastindex(tTM)
            for it = 1:_num_tests
                n = rand(1:end_idx)
                @test test_integ((t,x)->exactsol(t,x), tTM[n], qTM[:,n], q0, δq0)
            end
        end
    end

    @testset "Pendulum with constant torque" begin
        @taylorize function pendulum!(dx, x, p, t)
            si = sin(x[1])
            aux = 2 *  si
            dx[1] = x[2]
            dx[2] = aux + 8*x[3]
            dx[3] = zero(x[1])
            nothing
        end
        # Conserved quantity
        ene_pendulum(x) = x[2]^2/2 + 2 * cos(x[1]) - 8 * x[3]

        # Initial conditions
        tini, tend = 0.0, 12.0
        q0 = [1.1, 0.1, 0.0]
        δq0 = IntervalBox(-0.1 .. 0.1, -0.1 .. 0.1, 0..0)
        X0 = IntervalBox(q0 .+ δq0)
        ene0 = ene_pendulum(X0)

        # Parameters
        abstol = 1e-10
        orderQ = 3
        orderT = 10
        ξ = set_variables("ξ", order=2*orderQ, numvars=length(q0))

        tTM, qv, qTM = validated_integ(pendulum!, X0, tini, tend, orderQ, orderT, abstol);
        @test all(ene0 .⊆ ene_pendulum.(qv))

        tTM, qv, qTM = validated_integ2(pendulum!, X0, tini, tend, orderQ, orderT, abstol,
            validatesteps=32);
        @test all(ene0 .⊆ ene_pendulum.(qv))

        # Initial conditions 2
        q0 = [1.1, 0.1, 0.0]
        δq0 = IntervalBox(-0.1 .. 0.1, -0.1 .. 0.1, -0.01 .. 0.01)
        X0 = IntervalBox(q0 .+ δq0)
        ene0 = ene_pendulum(X0)

        tTM, qv, qTM = validated_integ(pendulum!, X0, tini, tend, orderQ, orderT, abstol);
        @test all(ene0 .⊆ ene_pendulum.(qv))

        tTM, qv, qTM = validated_integ2(pendulum!, X0, tini, tend, orderQ, orderT, abstol,
            validatesteps=32);
        @test all(ene0 .⊆ ene_pendulum.(qv))
    end
end
