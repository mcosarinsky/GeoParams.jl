module Conductivity

# This implements different methods to specify conductivity of rocks
#
# If you want to add a new method here, feel free to do so. 
# Remember to also export the function name in GeoParams.jl (in addition to here)

using Parameters, LaTeXStrings, Unitful
using ..Units
using GeoParams: AbstractMaterialParam, AbstractMaterialParamsStruct
import Base.show

abstract type AbstractConductivity <: AbstractMaterialParam end

export  ComputeConductivity,                # calculation routines
        ComputeConductivity!,
        ConstantConductivity,               # constant
        T_Conductivity_Whittacker,          # T-dependent heat capacity
        TP_Conductivity,                    # TP dependent conductivity
        Set_TP_Conductivity                 # Routine to set pre-defined parameters

# Constant Conductivity -------------------------------------------------------
"""
    ConstantConductivity(k=3.0W/m/K)
    
Set a constant conductivity
```math  
    k  = cst
```
where ``k`` is the thermal conductivity [``W/m/K``].
"""
@with_kw_noshow mutable struct ConstantConductivity <: AbstractConductivity
    equation::LaTeXString   =   L"k = cst"     
    k::GeoUnit              =   3.0Watt/m/K               
end

# Calculation routine
function ComputeConductivity(P, T, s::ConstantConductivity)
    @unpack k   = s

    if length(T)>1
        return Value(k).*ones(size(T))
    else
        return Value(k)
    end
end

"""
    ComputeConductivity(k_array::AbstractArray{<:AbstractFloat,N},P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, s::ConstantConductivity) where N

In-place routine to compute constant conductivity    
"""
function ComputeConductivity!(k_array::AbstractArray{<:AbstractFloat,N},P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, s::ConstantConductivity) where N
    @unpack k   = s
    
    k_array .= ustrip(Value(k))
    
    return nothing
end

# Print info 
function show(io::IO, g::ConstantConductivity)  
    print(io, "Constant conductivity: k=$(g.k.val)")  
end
#-------------------------------------------------------------------------


# Temperature dependent conductivity -------------------------------
"""
    T_Conductivity_Whittacker()
    
Sets a temperature-dependent conductivity following the parameterization of *Whittacker et al. (2009), Nature.* 
Their parameterization is originally given for the thermal diffusivity, together with a parameterization for thermal conductivity, which allows us 
```math  
    Cp = a + b T - c/T^2 
```
```math  
    \\kappa = d/T - e, if T<=846K
```
```math  
    \\kappa = f - g*T, if T>846K
```
```math    
    \\rho = 2700 kg/m3
```
```math
    k = \\kappa Cp \\rho
```

where ``Cp`` is the heat capacity [``J/mol/K``], and ``a,b,c`` are parameters that dependent on the temperature `T`:
- a = 199.50 J/mol/K    if T<= 846 K
- a = 199.50 J/mol/K    if T> 846 K
- b = 0.0857J/mol/K^2   if T<= 846 K
- b = 0.0323J/mol/K^2   if T> 846 K
- c = 5e6J/mol*K        if T<= 846 K
- c = 47.9e-6J/mol*K    if T> 846 K
- d = 576.3m^2/s*K      
- e = 0.062m^2/s        
- f = 0.732m^2/s        
- g = 0.000135m^2/s/K 
"""
@with_kw_noshow mutable struct T_Conductivity_Whittacker <: AbstractConductivity
    # Note: the resulting curve of k was visually compared with Fig. 2 of the paper
    equation::LaTeXString   =   L"k = f(T) "     
    a0::GeoUnit             =   199.5J/mol/K                # prefactor for low T       (T<= 846 K)
    a1::GeoUnit             =   229.32J/mol/K               # prefactor for high T      (T>  846 K)
    b0::GeoUnit             =   0.0857J/mol/K^2             # linear term for low T     (T<= 846 K)
    b1::GeoUnit             =   0.0323J/mol/K^2             # linear term for high T    (T>  846 K)
    c0::GeoUnit             =   5e6J/mol*K                  # quadratic term for low T  (T<= 846 K)
    c1::GeoUnit             =   47.9e-6J/mol*K              # quadratic term for high T (T>  846 K)
    molmass::GeoUnit        =   0.22178kg/mol               # average molar mass 
    Tcutoff::GeoUnit        =   846K                        # cutoff temperature
    rho::GeoUnit            =   2700kg/m^3                  # Density they use for an average crust
    d::GeoUnit              =   576.3*1e-6m^2/s*K           # diffusivity parameterization
    e::GeoUnit              =   0.062*1e-6m^2/s             # diffusivity parameterization
    f::GeoUnit              =   0.732*1e-6m^2/s             # diffusivity parameterization
    g::GeoUnit              =   0.000135*1e-6m^2/s/K        # diffusivity parameterization
end

# Calculation routine
function ComputeConductivity(P,T, s::T_Conductivity_Whittacker)
    @unpack a0,a1,b0,b1,c0,c1,molmass,Tcutoff,rho,d,e,f,g   = s
    
    ρ  = Value(rho)
    k  = zeros(size(T))*   Value(a0)/Value(molmass)*ρ*Value(e)  # the last multiplication ensures the correct units even for non-dimensional cases
    
    for i in eachindex(T)
        if T[i] <= Value(Tcutoff)
            a,b,c = Value(a0),Value(b0),Value(c0)
            κ     = Value(d)/T[i] - Value(e)  
        else
            a,b,c = Value(a1),Value(b1),Value(c1)
            κ     = Value(f) - Value(g)*T[i]
        end
       
        cp = (a + b*T[i] - c/T[i]^2)/molmass # conductivity
        
        k[i] = κ*ρ*cp       # compute conductivity from diffusivity

    end

    return k
end

"""
    ComputeConductivity(k_array::AbstractArray{<:AbstractFloat,N},P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, s::T_Conductivity_Whittacker) where N

In-place routine to compute temperature-dependent conductivity    
"""
function ComputeConductivity!(k::AbstractArray{<:AbstractFloat,N},P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, s::T_Conductivity_Whittacker) where N
    @unpack a0,a1,b0,b1,c0,c1,molmass,Tcutoff,rho,d,e,f,g   = s
    a0,b0,c0    =   NumValue(a0),NumValue(b0),NumValue(c0)
    a1,b1,c1    =   NumValue(a1),NumValue(b1),NumValue(c1)
    ρ           =   NumValue(rho)
    d,e,f,g     =   NumValue(d),NumValue(e),NumValue(f), NumValue(g)
    Tcutoff     =   NumValue(Tcutoff)
    molmass     =   NumValue(molmass)

    ind         =   (T .<= Tcutoff)
    T_local     =   view(T, ind )
    k[ind]      =   (a0 .+ b0*T_local - c0./T_local.^2)/molmass .* (d./T_local .- e) .* ρ

    ind         =   (T .> Tcutoff)
    T_local     =   view(T, ind )
    k[ind]      =   (a1 .+ b1*T_local - c1./T_local.^2)/molmass  .* (f .- g.*T_local ) .* ρ
    
    return nothing
end

# Print info 
function show(io::IO, g::T_Conductivity_Whittacker)  
    print(io, "T-dependent conductivity following Whittacker et al. (2009) for average crust). \n");
end
#-------------------------------------------------------------------------

# Temperature (& Pressure) dependent conductivity -------------------------------
"""
    TP_Conductivity()
    
Sets a temperature (and pressure)-dependent conductivity parameterization as described in Gerya, Numerical Geodynamics (2nd edition, Table 21.2).
The general for  

```math  
    k = \\left( a_k +  {b_k \\over {T + c_k}} \\right) (1 + d_k P) 
```

where ``k`` is the conductivity [``W/K/m``], and ``a_k,b_k,c_k,d_k`` are parameters that dependent on the temperature `T` and pressure `P`:
- ``a_k`` = 1.18Watt/K/m    
- ``b_k`` = 474Watt/m 
- ``c_k`` = 77K       
- ``d_k`` = 0/MPa       
"""
@with_kw_noshow mutable struct TP_Conductivity <: AbstractConductivity
    equation::LaTeXString   =   L"k = \left(a_k + {b_k/{T + c_k}} \right)*(1 + d_k*P) "     
    a::GeoUnit              =   1.18Watt/K/m        # empirical fitting term
    b::GeoUnit              =   474Watt/m           # empirical fitting term
    c::GeoUnit              =   77K                 # empirical fitting term
    d::GeoUnit              =   0/MPa               # empirical fitting term
    Comment::String         =   ""                  # Some remarks you want to add about this creep law implementation
    BibTex_Reference        =   ""                  # BibTeX reference
end


"""
    Set_TP_Conductivity["Name of temperature(-pressure) dependent conductivity"]
    
This is a dictionary with pre-defined laws:
- "UpperCrust"    
- "LowerCrust"
- "OceanicCrust"
- "Mantle"

# Example
```julia 
julia> k=Set_TP_Conductivity["Mantle"]
T/P dependent conductivity: k = (0.73 W K⁻¹ m⁻¹ + 1293 W m⁻¹/(T + 77 K))*(1 + 4.0e-5 MPa⁻¹*P)  
```

"""
Set_TP_Conductivity = Dict([
    ("UpperCrust", 
        TP_Conductivity( a=0.64Watt/K/m, b=807Watt/m, c=77K, d=0/MPa, 
            Comment="Sediment/upper crust T-dependent conductivity, as listed in table 21.2 of Gerya et al. | Reference still to be verified!")
    )
    
    ("LowerCrust", 
        TP_Conductivity( a=1.18Watt/K/m, b=474Watt/m, c=77K, d=0/MPa, 
            Comment="Lower crust T-dependent conductivity, as listed in table 21.2 of Gerya et al. | Reference still to be verified!")
    )

    ("OceanicCrust", 
        TP_Conductivity( a=1.18Watt/K/m, b=474Watt/m, c=77K, d=0/MPa, 
            Comment="Oceanic crust T-dependent conductivity, as listed in table 21.2 of Gerya et al. | Reference still to be verified!")
    )
    
    ("Mantle", 
        TP_Conductivity( a=0.73Watt/K/m, b=1293Watt/m, c=77K, d=0.00004/MPa, 
            Comment="Mantle T-dependent conductivity, as listed in table 21.2 of Gerya et al. | Reference still to be verified!")
    )

])


# Calculation routine
function ComputeConductivity(P,T, s::TP_Conductivity)
    @unpack a,b,c,d   = s
    
    a_k, b_k = Value(a), Value(b)
    c_k, d_k = Value(c), Value(d)

    k  = zeros(size(T))*   a_k  # the last multiplication ensures the correct units even for non-dimensional cases
    
    if ustrip(d_k)==0
        for i in eachindex(T)
            k[i] = a_k + b_k/(T[i] + c_k)
        end
    else
        if size(T) != size(P)
            error("Size of P and T arrays should be the same") 
        end

        for i in eachindex(T)
            k[i] = (a_k + b_k/(T[i] + c_k))*(1 + d_k*P[i])
        end
    end

    return k
end

# Calculation routine
function ComputeConductivity!(K::AbstractArray{T, N}, P::AbstractArray{T, N},Temp::AbstractArray{T, N}, s::TP_Conductivity) where{T<:AbstractFloat, N}
    @unpack a,b,c,d   = s
    
    a_k, b_k = NumValue(a), NumValue(b)
    c_k, d_k = NumValue(c), NumValue(d)

    if d_k==0
        K[:] = a_k .+ b_k./(Temp .+ c_k)
    else
        K[:] = (a_k .+ b_k./(Temp .+ c_k)).*(1.0 .+ d_k.*P)
    end

    return nothing
end


# Print info 
function show(io::IO, g::TP_Conductivity)  
    if ustrip(Value(g.d))==0
        print(io, "T/P dependent conductivity: k = $(g.a.val) + $(g.b.val)/(T + $(g.c.val))  \n");
    else
        print(io, "T/P dependent conductivity: k = ($(g.a.val) + $(g.b.val)/(T + $(g.c.val)))*(1 + $(g.d.val)*P)  \n");
    end
end
#-------------------------------------------------------------------------


# Help info for the calculation routines
"""
    k = ComputeConductivity(P, T, s:<AbstractConductivity)

Returns the thermal conductivity `k` at any temperature `T` and pressure `P` using any of the parameterizations implemented.

Currently available:
- ConstantConductivity
- T\\_Conductivity_Whittacker
- TP\\_Conductivity

# Example 
Using dimensional units
```julia
julia> T  = (250:100:1250)*K;
julia> cp = T_HeatCapacity_Whittacker()
julia> Cp = ComputeHeatCapacity(0,T,cp)
```


"""
ComputeConductivity()


"""
    k = ComputeConductivity(T::Any, s::AbstractConductivity)

Computes conductivity if only temperature (and not pressure) is specified
"""
ComputeConductivity(T::Any, s::AbstractConductivity) =  ComputeConductivity(0,T, s)

"""
    k = ComputeConductivity(s::ConstantConductivity)

Returns conductivity if we are sure that we will only employ constant values throughout the simulation
"""
ComputeConductivity(s::ConstantConductivity) =  ComputeConductivity(0,0, s)


"""
    ComputeConductivity!(K::AbstractArray{<:AbstractFloat}, Phases::AbstractArray{<:Integer}, P::AbstractArray{<:AbstractFloat},Temp::AbstractArray{<:AbstractFloat}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct})

In-place computation of conductivity `K` for the whole domain and all phases, in case a vector with phase properties `MatParam` is provided, along with `P` and `Temp` arrays.
This assumes that the `Phase` of every point is specified as an Integer in the `Phases` array.

"""
function ComputeConductivity!(K::AbstractArray{T, N}, Phases::AbstractArray{<:Integer, N}, P::AbstractArray{T, N},Temp::AbstractArray{T, N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct, 1}) where {T<:AbstractFloat,N}

    for i = 1:length(MatParam)
        
        if !isnothing(MatParam[i].Conductivity)
            # Create views into arrays (so we don't have to allocate)
            ind = Phases .== i;
            K_local     =   view(K   , ind )
            P_local     =   view(P   , ind )
            T_local     =   view(Temp, ind )

            ComputeConductivity!(K_local, P_local, T_local, MatParam[i].Conductivity[1] ) 
        end
        
    end

end


"""
    ComputeConductivity!(k::AbstractArray{T,N}, PhaseRatios::AbstractArray{T, M}, P::AbstractArray{<:AbstractFloat,N},T::AbstractArray{<:AbstractFloat,N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct})

In-place computation of density `rho` for the whole domain and all phases, in case a vector with phase properties `MatParam` is provided, along with `P` and `T` arrays.
This assumes that the `PhaseRatio` of every point is specified as an Integer in the `PhaseRatios` array, which has one dimension more than the data arrays (and has a phase fraction between 0-1)

"""
function ComputeConductivity!(k::AbstractArray{T, N}, PhaseRatios::AbstractArray{T, M}, P::AbstractArray{T, N},Temp::AbstractArray{T, N}, MatParam::AbstractArray{<:AbstractMaterialParamsStruct, 1}) where {T<:AbstractFloat, N,M}
    
    if M!=(N+1)
        error("The PhaseRatios array should have one dimension more than the other arrays")
    end

    k .= 0.0;
    k_local     = zeros(size(k))
    for i = 1:length(MatParam)
        k_local .= 0.0
        Fraction    = selectdim(PhaseRatios,M,i);
        if (maximum(Fraction)>0.0) & (!isnothing(MatParam[i].Conductivity))

            ComputeConductivity!(k_local, P, Temp, MatParam[i].Conductivity[1] ) 

            k .= k .+ k_local.*Fraction
        end
        
    end

end


end