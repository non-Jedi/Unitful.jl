using Compat: AbstractRange

*(y::Units, r::AbstractRange) = *(r,y)
*(r::AbstractRange, y::Units) = range(first(r)*y, step(r)*y, length(r))
*(r::AbstractRange, y::Units, z::Units...) = *(x, *(y,z...))

Base.linspace(start::Quantity{<:Real}, stop, len::Integer) =
    _linspace(promote(start, stop)..., len)
Base.linspace(start, stop::Quantity{<:Real}, len::Integer) =
    _linspace(promote(start, stop)..., len)
Base.linspace(start::Quantity{<:Real}, stop::Quantity{<:Real}, len::Integer) =
    _linspace(promote(start, stop)..., len)
(Base.linspace(start::T, stop::T, len::Integer) where (T<:Quantity{<:Real})) =
    LinSpace{T}(start, stop, len)
(Base.linspace(start::T, stop::T, len::Integer) where (T<:Quantity{<:Integer})) =
    linspace(Float64, ustrip(start), ustrip(stop), len, 1)*unit(T)

function _linspace(start::Quantity{T}, stop::Quantity{T}, len::Integer) where {T}
    dimension(start) != dimension(stop) && throw(DimensionError(start, stop))
    linspace(start, stop, len)
end
# first promote start and stop, leaving step alone
colon(start::A, step, stop::C) where {A<:Real,C<:Quantity} = colonstartstop(start,step,stop)
colon(start::A, step, stop::C) where {A<:Quantity,C<:Real} = colonstartstop(start,step,stop)
colon(a::T, b::Quantity, c::T) where {T<:Real} = colon(promote(a,b,c)...)
colon(start::Quantity{<:Real}, step, stop::Quantity{<:Real}) =
    colon(promote(start, step, stop)...)

# promotes start and stop
function colonstartstop(start::A, step, stop::C) where {A,C}
    dimension(start) != dimension(stop) && throw(DimensionError(start, stop))
    colon(convert(promote_type(A,C),start), step, convert(promote_type(A,C),stop))
end

function colon(start::A, step::B, stop::A) where A<:Quantity{<:Real} where B<:Quantity{<:Real}
    dimension(start) != dimension(step) && throw(DimensionError(start, step))
    colon(promote(start, step, stop)...)
end

# Traits for quantities using triangular dispatch
import Base: TypeOrder, TypeArithmetic, HasOrder,
    ArithmeticRounds, ArithmeticOverflows
(::Type{TypeOrder})(::Type{<:Quantity{<:Real}}) = HasOrder()
(::Type{TypeArithmetic})(::Type{<:Quantity{<:AbstractFloat}}) =
    ArithmeticRounds()
(::Type{TypeArithmetic})(::Type{<:Quantity{<:Integer}}) =
    ArithmeticOverflows()

(colon(start::T, step::T, stop::T) where T <: Quantity{<:Real}) =
    _colon(TypeOrder(T), TypeArithmetic(T), start, step, stop)
_colon(::HasOrder, ::Any, start::T, step, stop::T) where {T} = StepRange(start, step, stop)
_colon(::HasOrder, ::ArithmeticRounds, start::T, step, stop::T) where {T} =
    StepRangeLen(start, step, floor(Int, (stop-start)/step)+1)
_colon(::Any, ::Any, start::T, step, stop::T) where {T} =
    StepRangeLen(start, step, floor(Int, (stop-start)/step)+1)

# Opt into TwicePrecision functionality
*(x::Base.TwicePrecision, y::Units) = Base.TwicePrecision(x.hi*y, x.lo*y)
*(x::Base.TwicePrecision, y::Quantity) = (x * ustrip(y)) * unit(y)
function colon(start::T, step::T, stop::T) where (T<:Quantity{S}
        where S<:Union{Float16,Float32,Float64})
    # This will always return a StepRangeLen
    return colon(ustrip(start), ustrip(step), ustrip(stop)) * unit(T)
end
function Base.linspace(start::T, stop::T, len::Integer) where (T<:Quantity{S}
    where S<:Union{Float16,Float32,Float64})
    linspace(ustrip(start), ustrip(stop), len) * unit(T)
end

# No need to confuse things by changing the type once units are on there,
# if we can help it.
*(r::StepRangeLen, y::Units) = StepRangeLen(r.ref*y, r.step*y, length(r), r.offset)
*(r::LinSpace, y::Units) = LinSpace(r.start*y, r.stop*y, length(r))
*(r::StepRange, y::Units) = StepRange(r.start*y, r.step*y, r.stop*y)

function range(a::T, st::T, len::Integer) where (T<:Quantity{S}
        where S<:Union{Float16,Float32,Float64})
    return range(ustrip(a), ustrip(st), len) * unit(T)
end
range(a::Quantity{<:Real}, st::Quantity{<:AbstractFloat}, len::Integer) =
    range(float(a), st, len)
range(a::Quantity{<:AbstractFloat}, st::Quantity{<:Real}, len::Integer) =
    range(a, float(st), len)
function range(a::Quantity{<:AbstractFloat}, st::Quantity{<:AbstractFloat}, len::Integer)
    dimension(a) != dimension(st) && throw(DimensionError(a, st))
    range(promote(a, st)..., len)
end
range(a::Quantity, st::Real, len::Integer) = range(promote(a, st)..., len)
range(a::Real, st::Quantity, len::Integer) = range(promote(a, st)..., len)

# the following is needed to give sane error messages when doing e.g. range(1°, 2V, 5)
function range(a::T, step, len::Integer) where {T<:Quantity}
    dimension(a) != dimension(step) && throw(DimensionError(a,step))
    return Base._range(TypeOrder(T), TypeArithmetic(T), a, step, len)
end
