using Test
using LogicCircuits

include("../helper/validate_sdd.jl")

@testset "SDD tests" begin

   # just to make code coverage happy
   @test istrue(SddTrueNode())
   @test isfalse(SddFalseNode())

end

@testset "CNF compiler tests" begin

   cnf = zoo_cnf("easy/C17_mince.cnf")
   vtree = zoo_vtree("easy/C17_mince.min.vtree");
   mgr = TrimSddMgr(vtree)
      
   @test_throws Exception compile(mgr.left, cnf)
   @test_throws Exception compile(right_most_descendent(mgr), cnf)

   @test compile(mgr, cnf) === mgr(cnf)

   cnfs = [ 
            ("easy","C17_mince",32,92,45)
            ("easy","majority_mince",32,132,61)
            ("easy","b1_mince",8,169,84)
            ("easy","cm152a_mince",2048,127,62)
            ("iscas89","s208.1.scan",262144,1942,927)
          ]
   
          
   for (suite, name, count, size, nodes) in cnfs

      cnf = zoo_cnf("$suite/$name.cnf")
      vtree = zoo_vtree("$suite/$name.min.vtree");

      mgr = TrimSddMgr(vtree)
      # cnfΔ = @time compile_cnf(mgr, cnf)
      cnfΔ = compile(mgr, cnf)

      validate(cnfΔ)
      
      @test model_count(cnfΔ) == count
      @test sdd_size(cnfΔ) == size
      @test sdd_num_nodes(cnfΔ) == nodes

   end

end