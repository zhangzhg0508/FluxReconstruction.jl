using FluxRC, KitBase, Plots, LinearAlgebra

cd(@__DIR__)
ps = UnstructPSpace("square.msh")

N = deg = 2
Np = (N + 1) * (N + 2) ÷ 2
ncell = size(ps.cellid, 1)
nface = size(ps.faceType, 1)

J = rs_jacobi(ps.cellid, ps.points)

spg = global_sp(ps.points, ps.cellid, N)
fpg = global_fp(ps.points, ps.cellid, N)

pl, wl = tri_quadrature(N)

V = vandermonde_matrix(N, pl[:, 1], pl[:, 2]) # √
Vr, Vs = ∂vandermonde_matrix(N, pl[:, 1], pl[:, 2]) 
∂l = ∂lagrange(V, Vr, Vs) # √

ϕ = correction_field(N, V)

pf, wf = triface_quadrature(N)
ψf = zeros(3, N+1, Np)
for i = 1:3
    ψf[i, :, :] .= vandermonde_matrix(N, pf[i, :, 1], pf[i, :, 2])
end

lf = zeros(3, N+1, Np)
for i = 1:3, j = 1:N+1
    lf[i, j, :] .= V' \ ψf[i, j, :]
end

a = -1.0
u = zeros(size(ps.cellid, 1), Np)
for i in axes(u, 1), j in axes(u, 2)
    #u[i, j] = max(exp(-300 * ((spg[i, j, 1] - 0.5)^2 + (spg[i, j, 2] - 0.5)^2)), 1e-4)
    u[i, j] = max(exp(-100 * ((spg[i, j, 1] - ps.cellCenter[1211, 1])^2 + (spg[i, j, 2] - ps.cellCenter[1211, 2])^2)), 1e-4)
end

f = zeros(size(ps.cellid, 1), Np, 2)
for i in axes(f, 1)
    #xr, yr = ps.points[ps.cellid[i, 2], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    #xs, ys = ps.points[ps.cellid[i, 3], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    for j in axes(f, 2)
        fg = a * u[i, j]
        gg = a * u[i, j]
        #f[i, j, :] .= [ys * fg - xs * gg, -yr * fg + xr * gg] ./ det(J[i])
        f[i, j, :] .= inv(J[i]) * [fg, gg] #/ det(J[i])
    end
end # √

u_face = zeros(ncell, 3, deg+1)
f_face = zeros(ncell, 3, deg+1, 2)
for i in 1:ncell, j in 1:3, k in 1:deg+1
    u_face[i, j, k] = sum(u[i, :] .* lf[j, k, :])
    f_face[i, j, k, 1] = sum(f[i, :, 1] .* lf[j, k, :])
    f_face[i, j, k, 2] = sum(f[i, :, 2] .* lf[j, k, :])
end

n = [[0.0, -1.0], [1/√2, 1/√2], [-1.0, 0.0]]

fn_face = zeros(ncell, 3, deg+1)
for i in 1:ncell, j in 1:3, k in 1:deg+1
    fn_face[i, j, k] = sum(f_face[i, j, k, :] .* n[j])
end

f_interaction = zeros(ncell, 3, deg+1, 2)
au = zeros(2)
for i = 1:ncell, j = 1:3, k = 1:deg+1
    fL = J[i] * f_face[i, j, k, :]

    ni, nj, nk = neighbor_fpidx([i, j, k], ps, fpg)

    fR = zeros(2)
    if ni > 0
        fR .= J[ni] * f_face[ni, nj, nk, :]

        @. au = (fL - fR) / (u_face[i, j, k] - u_face[ni, nj, nk] + 1e-6)
        @. f_interaction[i, j, k, :] = 
            0.5 * (fL + fR) #-
            #0.5 * abs(au) * (u_face[i, j, k] - u_face[ni, nj, nk])
    else
        @. f_interaction[i, j, k, :] = 0.0
    end

    f_interaction[i, j, k, :] .= inv(J[i]) * f_interaction[i, j, k, :]
end

fn_interaction = zeros(ncell, 3, deg+1)
for i in 1:ncell
    for j in 1:3, k in 1:deg+1
        fn_interaction[i, j, k] = sum(f_interaction[i, j, k, :] .* n[j])
    end
end

rhs1 = zeros(ncell, Np)
for i in axes(rhs1, 1), j in axes(rhs1, 2)
    rhs1[i, j] = -sum(f[i, :, 1] .* ∂l[j, :, 1]) - sum(f[i, :, 2] .* ∂l[j, :, 2])
end

rhs2 = zero(rhs1)
for i in 1:ncell
    xr, yr = ps.points[ps.cellid[i, 2], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    xs, ys = ps.points[ps.cellid[i, 3], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    _J = xr * ys - xs * yr
    
    if ps.cellType[i] != 1
        for j in 1:Np
            #rhs2[i, j] = - sum((fn_interaction[i, :, :] .- fn_face[i, :, :]) .* ϕ[:, :, j]) / _J
            #rhs2[i, j] = - sum((fn_interaction[i, :, :] .- fn_face[i, :, :]) .* ϕ[:, :, j])
            rhs2[i, j] = - sum((fn_interaction[i, :, :] .- fn_face[i, :, :])) / 3
        end
    end
end

idx = 1211

rhs1[idx, :]

rhs2[idx, :]



fd, jd = 1, 1
u_face[idx, fd, jd]

u[idx, :]


ni, nj, nk = neighbor_fpidx([idx, 1, 1], ps, fpg)
u_face[ni, nj, nk]

u[ni, :]





ps.cellNeighbors[idx, :]



ps.cellFaces[idx, :]






du = rhs1 .+ rhs2

du[idx, :]


u .+= du * dt


write_vtk(ps.points, ps.cellid, u[:, 4])





f[idx, :, :]


f_face[idx, 2, 2, :]


fn_face[idx, 2, 2]




J[idx] * f[idx, 6, :]
J[idx] * f_face[idx, 1, 1, :]

fn_face[idx, 3, 3] * det(J[idx])