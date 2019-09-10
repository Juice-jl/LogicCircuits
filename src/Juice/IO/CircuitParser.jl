#####################
# general parser infrastructure for circuits
#####################

# The `ParserCombinator` library works correctly but is orders of magnitude too slow.
# Instead here we hardcode some simpler parsers to speed things up

"""
Load a smooth logical circuit from file.
Support file formats:
 * ".psdd" for PSDD files
 * ".circuit" for Logistic Circuit files
"""
function load_smooth_logical_circuit(file::String)::UnstLogicalCircuit△
    compile_smooth_logical(parse_circuit_file(file))
end

"""
Load a smooth structured logical circuit from file.
Support circuit file formats:
 * ".psdd" for PSDD files
 * ".circuit" for Logistic Circuit files
Supported vtree file formats:
 * ".vtree" for VTree files 
"""
function load_struct_smooth_logical_circuit(circuit_file::String, vtree_file::String)::StructLogicalCircuit△
    circuit_lines = parse_circuit_file(circuit_file)
    vtree_lines = parse_vtree_file(vtree_file)
    compile_smooth_struct_logical(circuit_lines, vtree_lines)
end


"""
Load a probabilistic circuit from file. 
Support circuit file formats:
 * ".psdd" for PSDD files
 """
function load_prob_circuit(file::String)::ProbCircuit△
    @assert endswith(file,".psdd")
    compile_prob(parse_psdd_file(file))
end

"""
Load a structured probabilistic circuit from file.
Support circuit file formats:
 * ".psdd" for PSDD files
Supported vtree file formats:
 * ".vtree" for VTree files 
"""
function load_struct_prob_circuit(circuit_file::String, vtree_file::String)::ProbCircuit△
    @assert endswith(circuit_file,".psdd")
    circuit_lines = parse_circuit_file(circuit_file)
    vtree_lines = parse_vtree_file(vtree_file)
    compile_struct_prob(circuit_lines, vtree_lines)
end

#####################
# parse based on file extension
#####################

function parse_circuit_file(file::String)::CircuitFormatLines
    if endswith(file,".circuit")
        parse_lc_file(file)
    elseif endswith(file,".psdd")
        parse_psdd_file(file)
    else
        throw("Cannot parse this file type as a circuit: $file")
    end
end

#####################
# parser of logistic circuit file format
#####################

const parens = r"\(([^\)]+)\)"

function parse_lc_decision_line(ln::String)::DecisionLine{LCElement}
    @assert startswith(ln, "D")
    head::SubString, tail::SubString = split(ln,'(',limit=2)
    head_tokens = split(head)
    head_ints::Vector{UInt32} = map(x->parse(UInt32,x),head_tokens[2:4])
    elems_str::String = "("*tail
    elems = Vector{LCElement}()
    for x in eachmatch(parens::Regex, elems_str)
        tokens = split(x[1], limit=3)
        weights::Vector{Float32} = map(x->parse(Float32,x), split(tokens[3]))
        elem = LCElement(parse(UInt32,tokens[1]), parse(UInt32,tokens[2]), weights)
        push!(elems,elem)
    end
    DecisionLine(head_ints[1],head_ints[2],head_ints[3],elems)
end

function parse_literal_line(ln::String)::WeightedLiteralLine
    @assert startswith(ln, "T") || startswith(ln, "F")
    tokens = split(ln)
    head_ints = map(x->parse(UInt32,x),tokens[2:4])
    weights = map(x->parse(Float32,x), tokens[5:end])
    lit = var2lit(head_ints[3])
    if startswith(ln, "F")
       lit = -lit # negative literal 
    end
    WeightedLiteralLine(head_ints[1],head_ints[2],lit,true,weights)
end

function parse_comment_line(ln::String)
    @assert startswith(ln, "c")
    CircuitCommentLine(lstrip(chop(ln, head = 1, tail = 0)))
end

function parse_lc_header_line(ln::String)
    @assert (ln == "Logistic Circuit") || (ln == "Logisitic Circuit")
    CircuitHeaderLine()
end

function parse_bias_line(ln::String)::BiasLine
    @assert startswith(ln, "B")
    tokens = split(ln)
    weights = map(x->parse(Float32,x), tokens[2:end])
    BiasLine(weights)
end

function parse_lc_file(file::String)::CircuitFormatLines
    q = CircuitFormatLines()
    open(file) do file # buffered IO does not seem to speed this up
        for ln in eachline(file)
            @assert !isempty(ln)
            if ln[1] == 'D'
                push!(q, parse_lc_decision_line(ln))
            elseif ln[1] == 'T' || ln[1] == 'F'
                push!(q, parse_literal_line(ln))
            elseif ln[1] == 'c'
                push!(q, parse_comment_line(ln))
            elseif ln[1] == 'L'
                push!(q, parse_lc_header_line(ln))
            elseif ln[1] == 'B'
                push!(q, parse_bias_line(ln))
            else
                error("Cannot parse logistic circuit file format line $ln")
            end
        end
    end
    q
end


#####################
# parser for PSDD circuit file format
#####################

function parse_psdd_decision_line(ln::String)::DecisionLine{PSDDElement}
    tokens = split(ln)
    head_ints::Vector{UInt32} = map(x->parse(UInt32,x),tokens[2:4])
    elems = Vector{PSDDElement}()
    for (p,s,w) in Iterators.partition(tokens[5:end],3)
        prime = parse(UInt32,p)
        sub = parse(UInt32,s)
        weight = parse(Float32,w)
        elem = PSDDElement(prime, sub, weight)
        push!(elems,elem)
    end
    DecisionLine(head_ints[1],head_ints[2],head_ints[3],elems)
end

function parse_true_leaf_line(ln::String)::WeightedNamedConstantLine
    tokens = split(ln)
    @assert length(tokens)==5
    head_ints = map(x->parse(UInt32,x),tokens[2:4])
    weight = parse(Float32,tokens[5])
    WeightedNamedConstantLine(head_ints[1],head_ints[2],head_ints[3],weight)
end

function parse_literal_line(ln::String)::UnweightedLiteralLine
    tokens = split(ln)
    @assert length(tokens)==4 "line has too many tokens: $ln"
    head_ints = map(x->parse(UInt32,x),tokens[2:3])
    lit = parse(Int32,tokens[4])
    UnweightedLiteralLine(head_ints[1],head_ints[2],lit,true)
end

function parse_psdd_file(file::String)::CircuitFormatLines
    q = CircuitFormatLines()
    open(file) do file # buffered IO does not seem to speed this up
        for ln in eachline(file)
            @assert !isempty(ln)
            if ln[1] == 'D'
                push!(q, parse_psdd_decision_line(ln))
            elseif ln[1] == 'T'
                push!(q, parse_true_leaf_line(ln))
            elseif ln[1] == 'L'
                push!(q, parse_literal_line(ln))
            elseif ln[1] == 'c'
                push!(q, parse_comment_line(ln))
            elseif startswith(ln,"psdd")
                push!(q, CircuitHeaderLine())
            else
                error("Cannot parse PSDD file format line $ln")
            end
        end
    end
    q
end