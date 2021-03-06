using PolyChaosODE,
    Distributions, DifferentialEquations, LaTeXStrings, LinearAlgebra, Parameters, Plots

### Linear ODE example ###

μ = 0.0
σ = sqrt(2.0) / 2

prob_dim = 4

struct ODEComp{T1,T2,T3}
    Λ::T1
    Q::T2
    error_vec::T3
end

function ode_func!(du, u, Λ, Q, error_vec, x, t)
    du .= Q' * diagm(Λ .+ error_vec .* x) * Q * u
end

function ode_func_closure!(du, u, comp::ODEComp, x, t)
    @unpack Λ, Q, error_vec = comp
    ode_func!(du, u, Λ, Q, error_vec, x, t)
end

P = randn(prob_dim, prob_dim)
Q = qr(P).Q
Λ = rand(Uniform(-0.200, -0.100), prob_dim)
error_vec = rand(Uniform(0.050, 0.100), prob_dim)

u0 = 10.0 .* randn(prob_dim)
tspan = (0.0, 5.0)
compartment = ODEComp(Λ, Q, error_vec)

function closed_form_variance(t)
    # z = Q * u = diag(e^(X_1), e^(X_2),..., e^(X_n)) * z0, with z0 = Q * u0 and X_i ~ N(Λ[i] * t, (σ * error_vec[i] * t)^2)
    return Q' .^ 2 * [
        (expm1((σ * error_vec[i] * t)^2)) *
        exp(2 * Λ[i] * t + (σ * error_vec[i] * t)^2) *
        (Q*u0)[i]^2 for i = 1:prob_dim
    ]
end

vars = Tuple(Normal(μ, σ) for i = 1:prob_dim)

stoch_galerkin_ode = StochGalerkinODE(ode_func_closure!, prob_dim, vars)
sol = stoch_galerkin_ode(u0, tspan, compartment; alg = VCABM())

step_t = 0.01
interval_t = tspan[1]:step_t:tspan[2]
sol_u = [sol(t) for t in interval_t]

pce_variance =
    compute_expectation_and_diag_variance(stoch_galerkin_ode, interval_t, sol_u)[2]
closed_form = [closed_form_variance(t) for t in interval_t]

error_arr =
    ((x, y) -> (sqrt.(x) .- sqrt.(y)) ./ sqrt.(y)).(pce_variance[2:end], closed_form[2:end])
abs_error_arr = (x -> abs.(x)).(error_arr)

plot_arr = mapreduce(transpose, vcat, abs_error_arr)

plot(
    interval_t[2:end],
    plot_arr;
    label = [L"err[\sigma_1]" L"err[\sigma_2]" L"err[\sigma_3]" L"err[\sigma_4]"],
    legend = :outertopright,
    size = (500, 400),
)
xlabel!(L"t")
ylabel!(L"\left\vert \frac{\sigma_{pce} - \sigma_{real}}{\sigma_{real}} \right\vert")

# savefig("linear_ode_example.png")
