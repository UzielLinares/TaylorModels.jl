# constructors.jl

const tupleTMs = (:TM1AbsRem, :TM1RelRem)
#=
Structs `TM1AbsRem{T}` and `TM1RelRem{T}` are essentially identical, except
the way the remainder is computed and that the remainder for `TM1AbsRem{T}`
must contain 0.
=#
for TM in tupleTMs

    @eval struct $(TM){T}
        pol  :: Taylor1{Interval{T}}    # polynomial approx (of order `ord`)
        rem  :: Interval{T}             # remainder
        x0   :: Interval{T}             # expansion point
        iI   :: Interval{T}             # interval of interest

        # Inner constructor
        function $(TM){T}(pol::Taylor1{Interval{T}}, rem::Interval{T},
                x0::Interval{T}, iI::Interval{T}) where {T}
            if $(TM) == TM1AbsRem
                @assert zero(T) ∈ rem && x0 ⊆ iI
            else
                @assert x0 ⊆ iI
            end
            return new{T}(pol, rem, x0, iI)
        end
    end

    # Outer constructors
     @eval $(TM)(pol::Taylor1{Interval{T}}, rem::Interval{T},
        x0::Interval{T}, iI::Interval{T}) where {T} = $(TM){T}(pol, rem, x0, iI)

    # Short-cut for independent variable
    @eval $(TM)(ord::Int, x0::Interval{T}, iI::Interval{T}) where {T} =
        $(TM)(x0 + Taylor1(Interval{T}, ord), zero(iI), x0, iI)

    # Short-cut for a constant
    @eval $(TM)(a::Interval{T}, ord::Int, x0::Interval{T},
        iI::Interval{T}) where {T} = $(TM)(Taylor1([a], ord), zero(iI), x0, iI)

    # Functions to retrieve the order and remainder
    @eval get_order(tm::$TM) = tm.pol.order
    @eval remainder(tm::$TM) = tm.rem
end


@doc """
    TM1AbsRem{T}

Taylor Models with Absolute Remainder. Corresponds to definition 2.1.3
(Mioara Joldes thesis).

""" TM1AbsRem

@doc """
    TM1RelRem{T}

Taylor Models with Relative Remainder. Corresponds to definition 2.3.2
(Mioara Joldes thesis).

""" TM1RelRem
