using FrankWolfe
using ProgressMeter
using Arpack
using Plots
using DoubleFloats
using ReverseDiff

import LinearAlgebra


n = Int(1e5)
k = 10000

xpi = rand(n);
total = sum(xpi);
const xp = xpi ./ total;

f(x) = LinearAlgebra.norm(x - xp)^2

function grad!(storage, x)
    storage .= 2 * (x - xp)
    return nothing
end

# better for memory consumption as we do coordinate-wise ops

function cf(x, xp)
    return @. LinearAlgebra.norm(x - xp)^2
end

# lmo = FrankWolfe.KSparseLMO(100, 1.0)
lmo = FrankWolfe.LpNormLMO{Float64,1}(1.0)
# lmo = FrankWolfe.ProbabilitySimplexOracle(1.0);
# lmo = FrankWolfe.UnitSimplexOracle(1.0);
x00 = FrankWolfe.compute_extreme_point(lmo, zeros(n))
# print(x0)

gradient = similar(x00)

FrankWolfe.benchmark_oracles(f, grad!, () -> randn(n), lmo; k=100)

# 1/t *can be* better than short step

println("\n==> Short Step rule - if you know L.\n")

x0 = copy(x00)
@time x, v, primal, dual_gap, trajectory_shortstep = FrankWolfe.frank_wolfe(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.Shortstep(2.0),
    print_iter=k / 10,
    memory_mode=FrankWolfe.InplaceEmphasis(),
    verbose=true,
    trajectory=true,
);

println("\n==> Short Step rule with momentum - if you know L.\n")

x0 = copy(x00)

@time x, v, primal, dual_gap, trajectoryM = FrankWolfe.frank_wolfe(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.Shortstep(2.0),
    print_iter=k / 10,
    memory_mode=FrankWolfe.OutplaceEmphasis(),
    verbose=true,
    trajectory=true,
    momentum=0.9,
);

println("\n==> Adaptive if you do not know L.\n")

x0 = copy(x00)

@time x, v, primal, dual_gap, trajectory_adaptive = FrankWolfe.frank_wolfe(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.Adaptive(L_est=100.0),
    print_iter=k / 10,
    memory_mode=FrankWolfe.InplaceEmphasis(),
    verbose=true,
    trajectory=true,
);

println("\n==> Agnostic if function is too expensive for adaptive.\n")

x0 = copy(x00)

@time x, v, primal, dual_gap, trajectory_agnostic = FrankWolfe.frank_wolfe(
    f,
    grad!,
    lmo,
    x0,
    max_iteration=k,
    line_search=FrankWolfe.Agnostic(),
    print_iter=k / 10,
    memory_mode=FrankWolfe.InplaceEmphasis(),
    verbose=true,
    trajectory=true,
);



data = [trajectory_shortstep, trajectory_adaptive, trajectory_agnostic, trajectoryM]
label = ["short step" "adaptive" "agnostic" "momentum"]


plot_trajectories(data, label)
