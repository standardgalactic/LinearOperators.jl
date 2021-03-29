function test_lsr1()
  ϵ = eps(Float64)
  rtol = sqrt(ϵ)

  @testset ExtendedTestSet "LSR1" begin
    n = 10
    mem = 5
    B = LSR1Operator(n, mem=mem, scaling=false)

    for t = 1:2
      @test norm(diag(B) - diag(Matrix(B))) <= rtol

      @test B.data.insert == 1
      @test norm(Matrix(B) - Matrix(1.0I, n, n)) <= ϵ

      # Test that only valid updates are accepted.
      s = simple_vector(Float64, n)
      y = B * s
      push!(B, s, y)
      @test B.data.insert == 1

      # Insert a few {s,y} pairs.
      for i = 1 : mem+2
        s = ones(n) * i
        y = [i; ones(n-1)]
        push!(B, s, y)
      end

      @test check_hermitian(B)
      @test norm(diag(B) - diag(Matrix(B))) <= rtol

      v = simple_vector(Float64, n)
      @test norm(B * v - v) > rtol
      reset!(B)
      @test B.data.scaling_factor == 1.0
      @test norm(B * v - v) < rtol
    end

    # test against full SR1 without scaling
    mem = n
    LB = LSR1Operator(n, mem=mem, scaling=false)
    B = Matrix(1.0I, n, n)

    function sr1!(B, s, y)
      # dense SR1 update
      ymBs = y - B * s
      denom = dot(ymBs, s)
      if abs(denom) >= 1.0e-8 + 1.0e-8 * norm(s) * norm(ymBs)
        B = B + ymBs * ymBs' / denom
      end
      return B
    end

    @test norm(Matrix(LB) - B) < rtol * norm(B)
    @test norm(diag(LB) - diag(B)) < rtol * norm(diag(B))

    for k = 1 : mem
      s = simple_vector(Float64, n)
      y = simple_vector(Float64, n)
      B = sr1!(B, s, y)
      LB = push!(LB, s, y)
      @test norm(Matrix(LB) - B) < rtol * norm(B)
      @test norm(diag(LB) - diag(B)) < rtol * norm(diag(B))
    end
  end

  @testset ExtendedTestSet "Different precision" begin
    n = 10
    mem = 5
    for T in (Float16, Float32, Float64, BigFloat)
      B = LSR1Operator(T, n, mem=mem)
      s = ones(T, n)
      y = ones(T, n)
      push!(B, s, y)
      @test eltype(B) == T
      v = [-(-one(T))^i for i = 1:n]
      @test eltype(B * v) == T
    end
  end

  @testset "LSR1 allocations" begin
    n = 100
    mem = 20
    B = LSR1Operator(n, mem=mem)
    for _ = 1 :2:n
      s = rand(n)
      y = rand(n)
      push!(B, s, y)
    end
    x = rand(n)
    B * x  # warmup
    nallocs = @allocated B * x
    @test nallocs == 0
    nallocs = @allocated diag!(B, x)
    @test nallocs == 0
  end

  @testset "LSR1 eigenvalues" begin
    n = 100
    mem = 20
    B = LSR1Operator(n, mem=mem)
    for _ = 1:2:n
      s = rand(n)
      y = rand(n)
      push!(B, s, y)
    end
    vals = eigs(B, nev=n)
    resid = vals[end]
    @test norm(resid) ≤ sqrt(eps(eltype(B)))
  end

  @testset "LSR1 product with a view" begin
    n = 100
    mem = 20
    B = LSR1Operator(n, mem=mem)
    for _ = 1:2:n
      s = rand(n)
      y = rand(n)
      push!(B, s, y)
    end
    x = rand(2 * n)
    y = view(x, 1:n)
    z = x[1:n]
    @test all(B * y .== B * z)
  end
end

test_lsr1()
