#------------------------------------------------------------------------------------------------------------------------
# Implements solution to the diffusion equation in an infinite medium as given in [1].
# Solutions are given in the steady-state, frequency, and time domains for an isotroptic source.
#
# [1] Patterson et. al., "Time resolved reflectance and transmittance for the noninvasive measurement of tissue optical properties," 
#     Appl. Opt. 28, 2331-2336 (1989)
#-------------------------------------------------------------------------------------------------------------------------
""" Structure containing inputs for simulating the fluence under the diffusion approximation in the infinite space."""
struct DAinf_params{T <: AbstractFloat} <: DiffusionParameters
    ρ::T                                 # distance away from isotropic point source (cm)
    μa::T                                # absorption coefficient (cm⁻¹)
    μsp::T                               # reduced scattering coefficient (cm⁻¹)
    n_med::T                             # medium's index of refraction
    ω::T                                 # modulation frequency (1/ns)
    t::Union{T, AbstractVector{T}}       # time vector (ns)

    # do not need to provide these arguments (calculated from previous inputs)
    D::T                                 # Diffusion coefficient                        
    ν::T                                 # Speed of light in medium (cm/ns)
    function DAinf_params{T}(ρ::T, μa::T, μsp::T, n_med::T, ω::T, t::Union{T, AbstractVector{T}}) where {T <: AbstractFloat}
        @assert ρ > zero(T) "ρ must be positive"
        @assert μa >= zero(T) "μa must greater than or equal to 0"
        @assert μsp > zero(T) "μsp must greater than 0"
        @assert n_med > zero(T) "n_med must be positive"
        @assert all(t .> zero(T)) "t must be positive"
        return new{T}(ρ, μa, μsp, n_med, ω, t, D_coeff(μsp), ν_coeff(n_med))
    end
end

"""
    Generator function for DAinf_params structure.

Provides parameters to use in the infinite space fluence calculation in either the CW, FD, or TD.
Arguments are given as keyword arguments (key = value)

# Keyword Arguments
- `ρ`: source-detector separation (cm⁻¹)
- `μa`: absorption coefficient (cm⁻¹)
- `μsp`: reduced scattering coefficient (cm⁻¹)
- `n_med`: medium's index of refraction
- `ω`: modulation frequency (1/ns)
- `t`: the time vector (ns). 

# Examples
```
julia> data = DAinf_params() # return default parameters
julia> data = DAinf_params(ρ = 1.5) # return ρ = 1.5 with the rest of the parameters given by defaults
julia> fluence_DA_inf_CW(data) # can then be used with corresponding functions
```
"""
function DAinf_params(;
    ρ::T = 1.0,
    μa::T = 0.1,
    μsp::T = 10.0,
    n_med::T = 1.0,
    ω::T = 0.0,
    t::Union{T, AbstractVector{T}} = 1.0
) where {T<:AbstractFloat}
    return DAinf_params{T}(ρ, μa, μsp, n_med, ω, t)
end

#-------------------------------------
# Steady-State Fluence 
#-------------------------------------
"""
    fluence_DA_inf_CW(ρ, μa, μsp)

Compute the steady-state fluence in an infinite medium.
This is an unsafe implementation and will not check parameters. ρ and μsp should be > 0.0 and μa >= 0.0.

# Arguments
- `ρ`: source-detector separation (cm⁻¹)
- `μa`: absorption coefficient (cm⁻¹)
- `μsp`: reduced scattering coefficient (cm⁻¹)

# Examples
```
julia> fluence_DA_inf_CW(1.0, 0.1, 10.0)
```
"""
function fluence_DA_inf_CW(ρ, μa, μsp)
    params = DiffusionKernelParams(μsp)
    return _kernel_fluence_DA_inf_CW(ρ, μa, μsp, params.D)
end
"""
    fluence_DA_inf_CW(data::DiffusionParameters)

Wrapper to `fluence_DA_inf_CW(ρ, μa, μsp)`

# Examples
```
julia> data = DAinf_params(ρ = 1.0) # use structure to generate inputs
julia> fluence_DA_inf_CW(data) # then call the function
```
"""
function fluence_DA_inf_CW(data::DiffusionParameters)
    return _kernel_fluence_DA_inf_CW(data.ρ, data.μa, data.μsp, data.D)
end

_kernel_fluence_DA_inf_CW(ρ, μa, μsp, D) = exp(-sqrt(3 * μsp * μa) * ρ) / (4 * π * ρ * D)

#-------------------------------------
# Frequency-Domain Fluence 
#-------------------------------------
"""
    fluence_DA_inf_FD(ρ, μa, μsp; ω = 0.0, n_med = 1.0)

Compute the fluence for a frequency modulated source in an infinite medium. 

# Arguments
- `ρ`: source-detector separation (cm⁻¹)
- `μa`: absorption coefficient (cm⁻¹)
- `μsp`: reduced scattering coefficient (cm⁻¹)

# Keyword Arguments
- `ω`: modulation frequency (1/ns)
- `n_med`: medium's index of refraction

# Examples
```
julia> fluence_DA_inf_FD(1.0, 0.1, 10.0, ω = 1.0, n_med = 1.4)
```
"""
function fluence_DA_inf_FD(ρ, μa, μsp; ω = 0.0, n_med = 1.0)
    params = DiffusionKernelParams(μsp, n_med)
    μa_complex = μa + ω * im / params.ν
    return _kernel_fluence_DA_inf_CW(ρ, μa_complex, μsp, params.D)
end
"""
    fluence_DA_inf_FD(data::DiffusionParameters)

Wrapper to `fluence_DA_inf_FD(ρ, μa, μsp; ω = 0.0, n_med = 1.0)`

# Examples
```
julia> data = DAinf_params(ω = 1.0) # use structure to generate inputs
julia> fluence_DA_inf_FD(data) # then call the function
```
"""
function fluence_DA_inf_FD(data::DiffusionParameters)
    μa_complex = data.μa + data.ω * im / data.ν
    return _kernel_fluence_DA_inf_CW(data.ρ, μa_complex, data.μsp, data.D)
end

#-------------------------------------
# Time-Domain Fluence 
#-------------------------------------
"""
    fluence_DA_inf_TD(t, ρ, μa, μsp; n_med = 1.0)

Compute the time-domain fluence in an infinite medium with Eqn. 3 of Patterson. et al. 1989.
This is an unsafe implementation and will not check parameters. t, ρ and μsp should be > 0.0 and μa >= 0.0.

# Arguments
- `t`: the time vector (ns). 
- `ρ`: source-detector separation (cm⁻¹)
- `μa`: absorption coefficient (cm⁻¹)
- `μsp`: reduced scattering coefficient (cm⁻¹)

# Keyword Arguments
- `n_med`= 1.0: medium's index of refraction

# Examples
```
julia> fluence_DA_inf_TD(0.1:0.5:5.0, 1.0, 0.1, 10.0, n_med = 1.4)
```
"""
function fluence_DA_inf_TD(t, ρ, μa, μsp; n_med = 1.0)
    params = DiffusionKernelParams(μsp, n_med)
    return map(t -> _kernel_fluence_DA_inf_TD(t, ρ, μa, params.ν, params.D), t)
end
"""
    fluence_DA_inf_TD(data::DiffusionParameters)

Wrapper to `fluence_DA_inf_TD(t, ρ, μa, μsp; n_med = 1.0)`.

# Examples
```
julia> data = DAinf_params(t = 0.1:0.05:2.0) # use structure to generate inputs
julia> fluence_DA_inf_TD(data) # then call the function
```
"""
function fluence_DA_inf_TD(data::DiffusionParameters)
    return map(t -> _kernel_fluence_DA_inf_TD(t, data.ρ, data.μa, data.ν, data.D), data.t)
end

@inline function _kernel_fluence_DA_inf_TD(t, ρ, μa, ν, D)
    tmp1 = 4 * D * ν * t
    ϕ = exp(-(ρ^2 / tmp1) - μa * ν * t)
    ϕ *= ν / ((tmp1 * π )^(3/2))
end
