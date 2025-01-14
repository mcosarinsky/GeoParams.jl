module Density

# This implements different methods to compute density
#
# If you want to add a new method here, feel free to do so. 
# Remember to also export the function name in GeoParams.jl (in addition to here)


using Parameters, LaTeXStrings, Unitful
using ..Units
using ..PhaseDiagrams
#using ..MaterialParameters
using GeoParams: AbstractMaterialParam, AbstractMaterialParamsStruct
import Base.show


abstract type AbstractDensity <: AbstractMaterialParam end

export  ComputeDensity,         # calculation routines
        ComputeDensity!,        # in place calculation
        ConstantDensity,        # constant
        PT_Density              # P & T dependent density

# Constant Density -------------------------------------------------------
"""
    ConstantDensity(ρ=2900kg/m^3)
    
Set a constant density:
```math  
    \\rho  = cst
```
where ``\\rho`` is the density [``kg/m^3``].
"""
@with_kw_noshow mutable struct ConstantDensity <: AbstractDensity
    equation::LaTeXString   =   L"\rho = cst"     
    ρ::GeoUnit              =   2900kg/m^3                # density
end

# Calculation routines
function ComputeDensity(P,T, s::ConstantDensity)
    @unpack ρ   = s
    if length(T)>1
        return Value(ρ).*ones(size(T))
    else
        return ρ*1.0
    end
end

function ComputeDensity!(rho::AbstractArray{<:AbstractFloat,N},P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, s::ConstantDensity) where N
    @unpack ρ   = s
    
    rho .= NumValue(ρ)
    
    return nothing
end

# Print info 
function show(io::IO, g::ConstantDensity)  
    print(io, "Constant density: ρ=$(g.ρ.val)")  
end
#-------------------------------------------------------------------------

# Pressure & Temperature dependent density -------------------------------
"""
    PT_Density(ρ0=2900kg/m^3, α=3e-5/K, β=1e-9/Pa, T0=0C, P=0MPa)
    
Set a pressure and temperature-dependent density:
```math  
    \\rho  = \\rho_0 (1.0 - \\alpha (T-T_0) + \\beta  (P-P_0) )  
```
where ``\\rho_0`` is the density [``kg/m^3``] at reference temperature ``T_0`` and pressure ``P_0``,
``\\alpha`` is the temperature dependence of density and ``\\beta`` the pressure dependence.

"""
@with_kw_noshow mutable struct PT_Density <: AbstractDensity
    equation::LaTeXString   =   L"\rho = \rho_0(1.0-\alpha (T-T_0) + \beta (P-P_0)"     
    ρ0::GeoUnit             =   2900kg/m^3                  # density
    α::GeoUnit              =   3e-5/K                      # T-dependence of density
    β::GeoUnit              =   1e-9/Pa                     # P-dependence of density
    T0::GeoUnit             =   0C                          # Reference temperature
    P0::GeoUnit             =   0MPa                        # Reference pressure
end

# Calculation routine
function ComputeDensity(P,T, s::PT_Density)
    @unpack ρ0,α,β,P0, T0   = s
    
    ρ = ρ0*(1.0 - α*(T - T0) + β*(P - P0) )

    return ρ
end

function ComputeDensity!(ρ, P,T, s::PT_Density)
    @unpack ρ0,α,β,P0, T0   = s

    ρ[:] = ρ0*(1.0 - α*(T-T0) + β*(P-P0) )

    return ρ
end

function ComputeDensity!(ρ::AbstractArray{<:AbstractFloat},P::AbstractArray{<:AbstractFloat},T::AbstractArray{<:AbstractFloat}, s::PT_Density)
    @unpack ρ0,α,β,P0, T0   = s
    ρ0 = NumValue(ρ0)
    α  = NumValue(α)
    β  = NumValue(β)
    P0 = NumValue(P0)
    T0 = NumValue(T0)
    
    ρ  .= ρ0*(1.0 .- α*( T .- T0) + β*(P .- P0) )

    return nothing
end

# Print info 
function show(io::IO, g::PT_Density)  
    print(io, "P/T-dependent density: ρ0=$(g.ρ0.val), α=$(g.α.val), β=$(g.β.val), T0=$(g.T0.val), P0=$(g.P0.val)")  
end
#-------------------------------------------------------------------------



#-------------------------------------------------------------------------
# Phase diagrams
"""
    ComputeDensity(P,T, s::PhaseDiagram_LookupTable)

Interpolates density as a function of `T,P`   
"""
function ComputeDensity(P,T, s::PhaseDiagram_LookupTable)
    return s.Rho.(T,P)
end

"""
    ComputeDensity!(rho::AbstractArray{<:AbstractFloat}, P::AbstractArray{<:AbstractFloat},T::AbstractArray{<:AbstractFloat}, s::PhaseDiagram_LookupTable)

In-place computation of density as a function of `T,P`, in case we are using a lookup table.    
"""
function ComputeDensity!(rho::AbstractArray{<:AbstractFloat}, P::AbstractArray{<:AbstractFloat},T::AbstractArray{<:AbstractFloat}, s::PhaseDiagram_LookupTable)
    rho[:] = s.Rho.(T,P)
    return nothing
end

#-------------------------------------------------------------------------

"""
    ComputeDensity!(rho::AbstractArray{<:AbstractFloat}, Phases::AbstractArray{<:Integer}, P::AbstractArray{<:AbstractFloat},T::AbstractArray{<:AbstractFloat}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct})

In-place computation of density `rho` for the whole domain and all phases, in case a vector with phase properties `MatParam` is provided, along with `P` and `T` arrays.
This assumes that the `Phase` of every point is specified as an Integer in the `Phases` array.

# Example
```julia
julia> MatParam    =   Array{MaterialParams, 1}(undef, 2);
julia> MatParam[1] =   SetMaterialParams(Name="Mantle", Phase=1,
                        CreepLaws= (PowerlawViscous(), LinearViscous(η=1e23Pa*s)),
                        Density   = PerpleX_LaMEM_Diagram("test_data/Peridotite.in"));
julia> MatParam[2] =   SetMaterialParams(Name="Crust", Phase=2,
                        CreepLaws= (PowerlawViscous(), LinearViscous(η=1e23Pa*s)),
                        Density   = ConstantDensity(ρ=2900kg/m^3));
julia> Phases = ones(Int64,400,400);
julia> Phases[:,20:end] .= 2
julia> rho     = zeros(size(Phases))
julia> T       =  ones(size(Phases))
julia> P       =  ones(size(Phases))*10
julia> ComputeDensity!(rho, Phases, P,T, MatParam)
julia> rho
400×400 Matrix{Float64}:
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46  …  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46  …  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
    ⋮                                            ⋮     ⋱                     ⋮                            
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46  …  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
 3334.46  3334.46  3334.46  3334.46  3334.46  3334.46     2900.0  2900.0  2900.0  2900.0  2900.0  2900.0  2900.0
```
The routine is made to minimize allocations:
```julia
julia> julia> @time ComputeDensity!(rho, Phases, P,T, MatParam)
0.003121 seconds (49 allocations: 3.769 MiB)
```
"""
function ComputeDensity!(rho::AbstractArray{<:AbstractFloat, N}, Phases::AbstractArray{<:Integer, N}, P::AbstractArray{<:AbstractFloat, N},T::AbstractArray{<:AbstractFloat, N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct, 1}) where N

    for i = 1:length(MatParam)

        if !isnothing(MatParam[i].Density)
            # Create views into arrays (so we don't have to allocate)
            ind = Phases .== i;
            rho_local   =   view(rho, ind )
            P_local     =   view(P  , ind )
            T_local     =   view(T  , ind )

            ComputeDensity!(rho_local, P_local, T_local, MatParam[i].Density[1] ) 
        end
        
    end

end

"""
    ComputeDensity!(rho::AbstractArray{<:AbstractFloat,N}, PhaseRatios::AbstractArray{<:AbstractFloat, M}, P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct})

In-place computation of density `rho` for the whole domain and all phases, in case a vector with phase properties `MatParam` is provided, along with `P` and `T` arrays.
This assumes that the `PhaseRatio` of every point is specified as an Integer in the `PhaseRatios` array, which has one dimension more than the data arrays (and has a phase fraction between 0-1)

"""
function ComputeDensity!(rho::AbstractArray{<:AbstractFloat, N}, PhaseRatios::AbstractArray{<:AbstractFloat, M}, P::AbstractArray{<:AbstractFloat, N},T::AbstractArray{<:AbstractFloat, N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct, 1}) where {N,M}
    
    if M!=(N+1)
        error("The PhaseRatios array should have one dimension more than the other arrays")
    end

    rho .= 0.0;
    for i = 1:length(MatParam)
        
        rho_local   = zeros(size(rho))
        Fraction    = selectdim(PhaseRatios,M,i);
        if (maximum(Fraction)>0.0) & (!isnothing(MatParam[i].Density))

            ComputeDensity!(rho_local, P, T, MatParam[i].Density[1] ) 

            rho .= rho .+ rho_local.*Fraction
        end
        
    end

end



end