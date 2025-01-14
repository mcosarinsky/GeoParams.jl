"""
    This provides units and creates a non-dimensionalization object
"""
module Units
using Unitful
import Unitful: superscript
using Parameters

import Base.show
using GeoParams: AbstractMaterialParam, AbstractMaterialParamsStruct, AbstractPhaseDiagramsStruct, PerpleX_LaMEM_Diagram


# Define additional units that are useful in geodynamics 
@unit    Myrs  "Myrs"   MillionYears    1000000u"yr"    false

function __init__()
    Unitful.register(Units)
end


Unitful.register(Units)

# Define a number of useful units
const km    = u"km"
const m     = u"m"
const cm    = u"cm"
const mm    = u"mm"
const Myrs  = u"Myrs"
const yr    = u"yr"
const s     = u"s"
const kg    = u"kg"
const g     = u"g"
const Pa    = u"Pa"
const MPa   = u"MPa"
const kbar  = u"kbar"
const Pas   = u"Pa*s"
const K     = u"K"
const C     = u"°C"
const mol   = u"mol"  
const kJ    = u"kJ"
const J     = u"J"
const Watt  = u"W"
const μW    = u"μW"


export 
    km, m, cm, mm, Myrs, yr, s, MPa, Pa, kbar, Pas, K, C, g, kg, mol, J, kJ, Watt, μW, 
    GeoUnit, GeoUnits, GEO_units, SI_units, NO_units, AbstractGeoUnits, 
    Nondimensionalize, Nondimensionalize!, Dimensionalize, Dimensionalize!,
    superscript, upreferred, GEO, SI, NONE, isDimensional, Value, NumValue, Unit

"""
AbstractGeoUnits

Abstract supertype for geo units.
"""
abstract type AbstractGeoUnits{TYPE} end

abstract type AbstractUnitType end

struct GEO <: AbstractUnitType end
struct SI  <: AbstractUnitType end
struct NONE<: AbstractUnitType end

"""
    Structure that holds a GeoUnit parameter and their dimensions

    Having that is useful, as non-dimensionalization removes the units from a number
    and we thus no longer know how to transfer it back to the correct units.

"""
mutable struct GeoUnit 
    val                 # the actual value ()
    unit :: Unitful.FreeUnits
end


GeoUnit(v::Unitful.Quantity)            =   GeoUnit(v, unit(v))     # store the units 
GeoUnit(v::Number)                      =   GeoUnit(v, NoUnits)     # in case we just have a number with no units
GeoUnit(v::Array)                       =   GeoUnit(v, NoUnits)     # array, no units
GeoUnit(v::Array{Unitful.Quantity})     =   GeoUnit(v, unit.(v))    # with units
GeoUnit(v::StepRange)                   =   GeoUnit(v, unit.(v))    # with units
Value(v::GeoUnit)                       =   v.val                   # get value of GeoUnit
NumValue(v::GeoUnit)                    =   ustrip(v.val)           # numeric value, with no units
Unit(v::GeoUnit)                        =   v.unit                  # extract unit

Base.convert(::Type{Float64}, v::GeoUnit)       =   v.val
Base.convert(::Type{GeoUnit}, v::Quantity)      =   GeoUnit(v) 
Base.convert(::Type{GeoUnit}, v::Number)        =   GeoUnit(v, NoUnits) 
Base.convert(::Type{GeoUnit}, v::Vector)        =   GeoUnit(v, unit(v[1])) 
Base.convert(::Type{GeoUnit}, v::Array)         =   GeoUnit(v, unit(v[1])) 
Base.convert(::Type{GeoUnit}, v::StepRangeLen)  =   GeoUnit(v, unit(v[1])) 
Base.convert(::Type{GeoUnit}, v::StepRange)     =   GeoUnit(v, unit(v[1])) 

# define a few basic routines so we can easily operate with GeoUnits
Base.show(io::IO, x::GeoUnit)   =   println(x.val)
Base.length(v::GeoUnit)         =   length(v.val)
Base.size(v::GeoUnit)           =   size(v.val)

Base.:*(x::GeoUnit, y::Number)  = x.val*y
Base.:+(x::GeoUnit, y::Number)  = x.val+y
Base.:/(x::GeoUnit, y::Number)  = x.val/y
Base.:-(x::GeoUnit, y::Number)  = x.val-y

Base.:*(x::GeoUnit, y::GeoUnit) = x.val*y.val
Base.:+(x::GeoUnit, y::GeoUnit) = x.val+y.val
Base.:/(x::GeoUnit, y::GeoUnit) = x.val/y.val
Base.:-(x::GeoUnit, y::GeoUnit) = x.val-y.val

Base.:*(x::Number, y::GeoUnit)  = y.val*x
Base.:+(x::Number, y::GeoUnit)  = y.val+x
Base.:/(x::Number, y::GeoUnit)  = x/y.val
Base.:-(x::Number, y::GeoUnit)  = x-y.val

Base.:*(x::GeoUnit, y::Quantity)  = GeoUnit(x.val*y, x.unit)
Base.:+(x::GeoUnit, y::Quantity)  = GeoUnit(x.val+y, x.unit)
Base.:/(x::GeoUnit, y::Quantity)  = GeoUnit(x.val/y, x.unit)
Base.:-(x::GeoUnit, y::Quantity)  = GeoUnit(x.val-y, x.unit)

Base.:*(x::GeoUnit, y::Array)   = GeoUnit(x.val*y, x.unit)
Base.:/(x::GeoUnit, y::Array)   = GeoUnit(x.val/y, x.unit)
Base.:+(x::GeoUnit, y::Array)   = GeoUnit(x.val+y, x.unit)
Base.:-(x::GeoUnit, y::Array)   = GeoUnit(x.val-y, x.unit)

Base.:*(x::Array, y::GeoUnit)   = GeoUnit(x*y.val, y.unit)
Base.:/(x::Array, y::GeoUnit)   = GeoUnit(x/y.val, y.unit)
Base.:+(x::Array, y::GeoUnit)   = GeoUnit(x +y.val, y.unit)
Base.:-(x::Array, y::GeoUnit)   = GeoUnit(x -y.val, y.unit)

Base.:*(x::GeoUnit, y::Vector)   = GeoUnit(x.val*y, x.unit)
Base.:/(x::GeoUnit, y::Vector)   = GeoUnit(x.val/y, x.unit)
Base.:+(x::GeoUnit, y::Vector)   = GeoUnit(x.val+y, x.unit)
Base.:-(x::GeoUnit, y::Vector)   = GeoUnit(x.val-y, x.unit)

Base.:*(x::GeoUnit, y::StepRange)   = GeoUnit(x.val*y, x.unit)
Base.:/(x::GeoUnit, y::StepRange)   = GeoUnit(x.val/y, x.unit)
Base.:+(x::GeoUnit, y::StepRange)   = GeoUnit(x.val+y, x.unit)
Base.:-(x::GeoUnit, y::StepRange)   = GeoUnit(x.val-y, x.unit)

Base.getindex(x::GeoUnit, i::Int64, j::Int64, k::Int64) = x.val[i,j,k]
Base.getindex(x::GeoUnit, i::Int64, j::Int64) = x.val[i,j]
Base.getindex(x::GeoUnit, i::Int64) = x.val[i]

Base.setindex!(x::GeoUnit, v::Any, i::Int64, j::Int64, k::Int64) = x.val[i,j,k] = v
Base.setindex!(x::GeoUnit, v::Any, i::Int64, j::Int64) = x.val[i,j] = v
Base.setindex!(x::GeoUnit, v::Any, i::Int64) = x.val[i] = v

"""
    GeoUnits

    Structure that holds parameters used for non-dimensionalization
"""
@with_kw_noshow struct GeoUnits{TYPE} 
    # Selectable input parameters
    temperature     =   1               #   Characteristic temperature  [C or K]
    length          =   1               #   Characteristic length unit  [km, m or -]
    stress          =   1               #   Characteristic stress unit  [MPa, Pa or -]
    time            =   1               #   Characteristic time unit    [Myrs, s pr -]
    viscosity       =   1

    # primary characteristic units
    K               =   1;                      # temperature in SI units for material parameter scaling
    s               =   1;                      # time in SI units for material parameter scaling
    m               =   1;                      # length in SI units for material parameter scaling
    Pa              =   1;                      # stress in SI units 
    kg              =   upreferred(Pa*m*s^2)    # compute mass from pascal. Note: this may result in very large values
    
    # Main SI units (used later for nondimensionalization)
    Length          =   m
    Mass            =   kg
    Time            =   s    
    Temperature     =   K
    Amount          =   1mol
    Second          =   s
    

    # Not defined, as they are not common in geodynamics:
    #Current
    #Luminosity
    
    # Derived units
    N               =   kg*m/s^2        # Newton
    J               =   N*m             # Joule
    W               =   J/s             # Watt
    area            =   m^2             # area   in SI units for material parameter scaling
    volume          =   m^3             # volume
    velocity        =   m/s             
    density         =   kg/m^3
    acceleration    =   m/s^2
    force           =   kg*m/s^2
    strainrate      =   1/s
    heatcapacity    =   J/kg/K 
    conductivity    =   W/m/K
    
    # Helpful
    SecYear         =   3600*24*365.25
    Myrs            =   1e6
    cmYear          =   SecYear*100     # to transfer m/s -> cm/yr
    
end

"""
    GEO_units(;length=1000km, temperature=1000C, stress=10MPa, viscosity=1e20Pas)

Creates a non-dimensionalization object using GEO units.

GEO units implies that upon dimensionalization, `time` will be in `Myrs`, `length` in `km`, stress in `MPa`, etc.
which is more convenient for typical geodynamic simulations than SI units
The characteristic values given as input can be in arbitrary units (`km` or `m`), provided the unit is specified.

# Examples:
```julia-repl
julia> CharUnits = GEO_units()
Employing GEO units 
Characteristic values: 
         length:      1000 km
         time:        0.3169 Myrs
         stress:      10 MPa
         temperature: 1000.0 °C
julia> CharUnits.velocity
1.0e-7 m s⁻¹
```
If we instead have a crustal-scale simulation, it is likely more appropriate to use a different characteristic `length`:
```julia-repl
julia> CharUnits = GEO_units(length=10km)
Employing GEO units 
Characteristic values: 
         length:      10 km
         time:        0.3169 Myrs
         stress:      10 MPa
         temperature: 1000.0 °C
```
"""
function GEO_units(;length=1000km, temperature=1000C, stress=10MPa, viscosity=1e20Pas)
    
    if unit(temperature)==NoUnits;  temperature = temperature*C;        end
    if unit(length)==NoUnits;       length      = length*u"km";         end
    if unit(stress)==NoUnits;       stress      = stress*u"MPa";        end
    if unit(viscosity)==NoUnits;    viscosity   = viscosity*u"Pa*s";    end
    
    T       =   uconvert(C,      temperature) 
    Le      =   uconvert(km,     length);
    Sigma   =   uconvert(MPa,    stress)
    Eta     =   uconvert(Pas,    viscosity)
    
    T_SI    =   uconvert(K,      T);
    Le_SI   =   uconvert(m,      Le);
    Sigma_SI=   uconvert(Pa,     Sigma)
    Time_SI =   Eta/Sigma_SI;
    t       =   uconvert(Myrs,   Time_SI)

    GeoUnits{GEO}(length=Le, temperature=T,      stress=Sigma,  viscosity=Eta, time=t,
                  m=Le_SI,   K=T_SI,   Pa=Sigma_SI,  s=Time_SI)
end


"""
    CharUnits = SI_units(length=1000m, temperature=1000K, stress=10Pa, viscosity=1e20)

Specify the characteristic values using SI units 

# Examples:
```julia-repl
julia> CharUnits = SI_units(length=1000m)
Employing SI units 
Characteristic values: 
         length:      1000 m
         time:        1.0e19 s
         stress:      10 Pa
         temperature: 1000.0 K
```
Note that the same can be achieved if the input is given in `km`:
```julia-repl
julia> CharUnits = SI_units(length=1km)
```
"""
function SI_units(;length=1000m, temperature=1000K, stress=10Pa, viscosity=1e20Pas)
    
    if unit(temperature)==NoUnits;  temperature = temperature*K;     end
    if unit(length)==NoUnits;       length      = length*u"m";         end
    if unit(stress)==NoUnits;       stress      = stress*u"Pa";        end
    if unit(viscosity)==NoUnits;    viscosity   = viscosity*u"Pa*s";    end
    
    T       =   uconvert(K,     temperature) 
    Le      =   uconvert(m,     length);
    Sigma   =   uconvert(Pa,    stress)
    Eta     =   uconvert(Pas,   viscosity)
    
    T_SI    =   uconvert(K,      T);
    Le_SI   =   uconvert(m,      Le);
    Sigma_SI=   uconvert(Pa,     Sigma)
    Time_SI =   Eta/Sigma_SI;
    t       =   uconvert(s,      Time_SI)

    GeoUnits{SI}(length=Le, temperature=T,      stress=Sigma,  viscosity=Eta, time=t,
                 m=Le_SI,   K=T_SI,   Pa=Sigma_SI,  s=Time_SI)
end

"""
    CharUnits = NO_units(length=1, temperature=1, stress=1, viscosity=1)
   
Specify the characteristic values in non-dimensional units

# Examples:
```julia-repl
julia> using GeoParams;
julia> CharUnits = NO_units()
Employing NONE units 
Characteristic values: 
         length:      1
         time:        1.0 
         stress:      1
         temperature: 1.0
```
"""
function NO_units(;length=1, temperature=1, stress=1, viscosity=1)
    
    if unit(temperature)!=NoUnits;  error("temperature should not have units")    end
    if unit(length)!=NoUnits;       error("length should not have units")    end
    if unit(stress)!=NoUnits;       error("stress should not have units")    end
    if unit(viscosity)!=NoUnits;    error("viscosity should not have units")    end
    
    T       =   temperature
    Le      =   length;
    Sigma   =   stress
    Eta     =   viscosity
    Time    =   Eta/Sigma;

    GeoUnits{NONE}(length=Le, temperature=T, stress=Sigma, viscosity=Eta, time=Time,
                 m=Le, K=T, Pa=Sigma, s=Time)
end

"""
    Nondimensionalize(param, CharUnits::GeoUnits{TYPE})

Nondimensionalizes `param` using the characteristic values specified in `CharUnits`

# Example 1
```julia-repl
julia> using GeoParams;
julia> CharUnits =   GEO_units();
julia> v         =   3cm/yr
3 cm yr⁻¹ 
julia> v_ND      =   Nondimensionalize(v, CharUnits) 
0.009506426344208684
```
# Example 2
In geodynamics one sometimes encounters more funky units
```julia-repl
julia> CharUnits =   GEO_units();
julia> A         =   6.3e-2MPa^-3.05*s^-1
0.063 MPa⁻³·⁰⁵ s⁻¹
julia> A_ND      =   Nondimensionalize(A, CharUnits) 
7.068716262102384e14
```

In case you are interested to see how the units of `A` look like in different units, use this function from the [Unitful](https://github.com/PainterQubits/Unitful.jl) package:
```julia-repl
julia> uconvert(u"Pa^-3.05*s^-1",A) 
3.157479571851836e-20 Pa⁻³·⁰⁵
```
and to see it decomposed in the basic `SI` units of length, mass and time:
```julia-repl
julia> upreferred(A)
3.1574795718518295e-20 m³·⁰⁵ s⁵·¹ kg⁻³·⁰⁵
```
"""
function Nondimensionalize(param, g::GeoUnits{TYPE}) where {TYPE}
    if typeof(param) == String
        param_ND = param # The parameter is a string, cannot be nondimensionalized
    elseif unit(param)!=NoUnits
        dim         =   Unitful.dimension(param);                   # Basic SI units
        char_val    =   1.0;
        foreach((typeof(dim).parameters[1])) do y
            val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
            pow = Float64(y.power)                                  # power by which it should be multiplied   
            char_val *= val^pow                                     # multiply characteristic value
        end
        param_ND = upreferred.(param)/char_val
    else
        param_ND = param # The parameter has no units, so there is no way to determine how to nondimensionize it 
    end
    return param_ND
end


function Nondimensionalize(param::Array, g::GeoUnits{TYPE}) where {TYPE}
    if unit(param[1])!=NoUnits
        dim         =   Unitful.dimension.(param);                   # Basic SI units
        char_val    =   1.0;
        foreach((typeof(dim[1]).parameters[1])) do y
            val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
            pow = Float64(y.power)                                  # power by which it should be multiplied   
            char_val *= val^pow                                     # multiply characteristic value
        end
        param_ND = upreferred.(param)/char_val
    else
        param_ND = param # The parameter has no units, so there is no way to determine how to nondimensionize it 
    end
    return param_ND
end

"""
    Nondimensionalize!(param::GeoUnit, CharUnits::GeoUnits{TYPE})

Nondimensionalizes `param` (given as GeoUnit) using the characteristic values specified in `CharUnits` in-place

# Example 1
```julia-repl
julia> using GeoParams;
julia> CharUnits =   GEO_units();
julia> v         =   GeoUnit(3cm/yr)
3 cm yr⁻¹ 
julia> Nondimensionalize!(v, CharUnits) 
0.009506426344208684
```
# Example 2
```julia-repl
julia> CharUnits =   GEO_units();
julia> A         =   GeoUnit(6.3e-2MPa^-3.05*s^-1)
0.063 MPa⁻³·⁰⁵ s⁻¹
julia> A_ND      =   Nondimensionalize(A, CharUnits) 
7.068716262102384e14
```
"""
function Nondimensionalize!(param::GeoUnit, g::GeoUnits{TYPE}) where {TYPE}
    if unit.(param.val)!=NoUnits
        dim         =   Unitful.dimension(param.val[1]);                   # Basic SI units
        char_val    =   1.0;
        foreach((typeof(dim).parameters[1])) do y
            val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
            pow = Float64(y.power)                                  # power by which it should be multiplied   
            char_val *= val^pow                                     # multiply characteristic value
        end
        param.val = upreferred.(param.val)/char_val;
    else
        param = param # The parameter has no units, so there is no way to determine how to nondimensionize it 
    end
end


function Nondimensionalize!(param::String, g::GeoUnits{TYPE}) where {TYPE}
    param_ND = param
    return nothing
end

function Nondimensionalize!(param::Array, g::GeoUnits{TYPE}) where {TYPE}
  
    if unit.(param[1])!=NoUnits
        dim         =   Unitful.dimension(param[1]);                   # Basic SI units
        char_val    =   1.0;
        foreach((typeof(dim).parameters[1])) do y
            val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
            pow = Float64(y.power)                                  # power by which it should be multiplied   
            char_val *= val^pow                                     # multiply characteristic value
        end
        param = upreferred.(param)/char_val;
    else
        param = param # The parameter has no units, so there is no way to determine how to nondimensionize it 
    end

end

"""
    Nondimensionalize!(MatParam::AbstractMaterialParam, CharUnits::GeoUnits{TYPE})

Non-dimensionalizes a material parameter structure (e.g., Density, CreepLaw)

"""
function Nondimensionalize!(MatParam::AbstractMaterialParam, g::GeoUnits{TYPE}) where {TYPE} 
    for param in fieldnames(typeof(MatParam))
        if typeof(getfield(MatParam, param))==GeoUnit
            z=getfield(MatParam, param)
            Nondimensionalize!(z, g)
            setfield!(MatParam, param, z)
        end
    end
end
    
"""
    Nondimensionalize!(phase_mat::MaterialParams, g::GeoUnits{TYPE})

Nondimensionalizes all fields within the Material Parameters structure that contain material parameters
"""
function Nondimensionalize!(phase_mat::AbstractMaterialParamsStruct, g::GeoUnits{TYPE}) where {TYPE} 

    for param in fieldnames(typeof(phase_mat))
        fld = getfield(phase_mat, param)
        if ~isnothing(fld)
            if typeof(fld[1]) <: AbstractPhaseDiagramsStruct
                
                # in case we employ a phase diagram 
                temp = PerpleX_LaMEM_Diagram(fld[1].Name, CharDim = g)
                
                setfield!(phase_mat, param, (temp,))
            else
                # otherwise non-dimensionalize 
                for i=1:length(fld)
                    if typeof(fld[i]) <: AbstractMaterialParam
                        Units.Nondimensionalize!(fld[i],g)
                    end
                end
            end
        end
    end
    phase_mat.Nondimensional = true
end

"""
    Dimensionalize(param, param_dim::Unitful.FreeUnits, CharUnits::GeoUnits{TYPE})

Dimensionalizes `param` into the dimensions `param_dim` using the characteristic values specified in `CharUnits`.  

# Example
```julia-repl
julia> CharUnits =   GEO_units();
julia> v_ND      =   Nondimensionalize(3cm/yr, CharUnits) 
0.031688087814028945
julia> v_dim     =   Dimensionalize(v_ND, cm/yr, CharUnits) 
3.0 cm yr⁻¹
```

"""
function Dimensionalize(param_ND, param_dim::Unitful.FreeUnits, g::GeoUnits{TYPE}) where {TYPE}

    dim         =   Unitful.dimension(param_dim);                   # Basic SI units
    char_val    =   1.0;
    foreach((typeof(dim).parameters[1])) do y
        val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
        pow = Float64(y.power)                                  # power by which it should be multiplied   
        char_val *= val^pow                                     # multiply characteristic value
    end
    param = uconvert.(param_dim, param_ND*char_val)
  
    return param
end

"""
    Dimensionalize!(param::GeoUnit, CharUnits::GeoUnits{TYPE})

Dimensionalizes `param` again to the values that it used to have using the characteristic values specified in `CharUnits`.  

# Example
```julia-repl
julia> CharUnits =   GEO_units();
julia> x = GeoUnit(3cm/yr)
julia> Nondimensionalize!(x, CharUnits)
julia> Dimensionalize!(x, CharUnits) 
3.0 cm yr⁻¹
```

"""
function Dimensionalize!(param::GeoUnit, g::GeoUnits{TYPE}) where {TYPE}
    
    dim         =   Unitful.dimension(param.unit);                   # Basic SI units
    char_val    =   1.0;
    foreach((typeof(dim).parameters[1])) do y
        val = upreferred(getproperty(g, Unitful.name(y)))       # Retrieve the characteristic value from structure g
        pow = Float64(y.power)                                  # power by which it should be multiplied   
        char_val *= val^pow                                     # multiply characteristic value
    end
    param.val = uconvert.(param.unit, param.val*char_val)
  
end

"""
    Dimensionalize!(MatParam::AbstractMaterialParam, CharUnits::GeoUnits{TYPE})

Dimensionalizes a material parameter structure (e.g., Density, CreepLaw)

"""
function Dimensionalize!(MatParam::AbstractMaterialParam, g::GeoUnits{TYPE}) where {TYPE} 

    for param in fieldnames(typeof(MatParam))
        if typeof(getfield(MatParam, param))==GeoUnit
            z=getfield(MatParam, param)
            Dimensionalize!(z, g)
            setfield!(MatParam, param, z)
        end
    end
    
end

"""
    isDimensional(MatParam::AbstractMaterialParam)

`true` if MatParam is in dimensional units.    
"""
function isDimensional(MatParam::AbstractMaterialParam)
    isDim = false;
    for param in fieldnames(typeof(MatParam))
        if typeof(getfield(MatParam, param))==GeoUnit
            z=getfield(MatParam, param)
            if unit(z.val)!=NoUnits
                isDim=true;
            end
        end
    end
    return isDim
end


"""
    Dimensionalize!(phase_mat::MaterialParams, g::GeoUnits{TYPE})

Dimensionalizes all fields within the Material Parameters structure that contain material parameters
"""
function Dimensionalize!(phase_mat::AbstractMaterialParamsStruct, g::GeoUnits{TYPE}) where {TYPE} 

    for param in fieldnames(typeof(phase_mat))
        fld = getfield(phase_mat, param)
        if ~isnothing(fld)
            for i=1:length(fld)
                if typeof(fld[i]) <: AbstractMaterialParam
                    Units.Dimensionalize!(fld[i],g)
                end
            end
        end
    end
    phase_mat.Nondimensional = false

end

# Define a view for the GEO_Units structure
function show(io::IO, g::GeoUnits{TYPE})  where {TYPE}
    print(io, "Employing $TYPE units \n",
              "Characteristic values: \n",  
              "         length:      $(g.length)\n",
              "         time:        $(round(ustrip(g.time),digits=4)) $(unit(g.time))\n",
              "         stress:      $(g.stress)\n",
              "         temperature: $(Float64(g.temperature))\n")
end



# This replaces the viewer of the Unitful package, such that the printing of units is done as floats (better)
function Unitful.superscript(i::Rational{Int64}; io=nothing) 
    string(superscript(float(i)))
    if io === nothing
        iocontext_value = nothing
    else
        iocontext_value = get(io, :fancy_exponent, nothing)
    end
    if iocontext_value isa Bool
        fancy_exponent = iocontext_value
    else
        v = get(ENV, "UNITFUL_FANCY_EXPONENTS", Sys.isapple() ? "true" : "false")
        t = tryparse(Bool, lowercase(v))
        fancy_exponent = (t === nothing) ? false : t
    end
    if fancy_exponent
        return superscript(float(i)) 
    else
        return  "^" * string(float(i)) 
    end

end

Unitful.superscript(i::Float64) = map(repr(i)) do c
    c == '-' ? '\u207b' :
    c == '1' ? '\u00b9' :
    c == '2' ? '\u00b2' :
    c == '3' ? '\u00b3' :
    c == '4' ? '\u2074' :
    c == '5' ? '\u2075' :
    c == '6' ? '\u2076' :
    c == '7' ? '\u2077' :
    c == '8' ? '\u2078' :
    c == '9' ? '\u2079' :
    c == '0' ? '\u2070' :
    c == '.' ? '\u0387' :
    error("unexpected character")
end



end
