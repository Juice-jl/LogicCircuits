using Test
using LogicCircuits
using DataFrames: DataFrame, DataFrameRow

@testset "Data utils" begin

    m = [1.1 2.1; 3.1 4.1; 5.1 6.1]
    df = DataFrame(m)
    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    
    batched_df = batch(df, 1)
    batched_dfb = batch(dfb, 1)
    
    @test num_examples(df) == 3
    @test num_examples(dfb) == 3
    @test num_examples(batched_df) == 3
    @test num_examples(batched_dfb) == 3

    @test num_features(df) == 2
    @test num_features(dfb) == 2
    @test num_features(batched_df) == 2
    @test num_features(batched_dfb) == 2
    
    @test example(df,2) isa Vector
    @test example(df,2)[1] == 3.1
    @test example(df,2)[2] == 4.1

    @test feature_values(df,2) == [2.1,4.1,6.1]
    @test feature_values(dfb,2) isa BitVector
    @test feature_values(dfb,2) == BitVector([false,true,true])

    @test isfpdata(df)
    @test !isfpdata(dfb)
    @test isfpdata(batched_df)
    @test !isfpdata(batched_dfb)
    @test !isfpdata(DataFrame([1 "2"; 3 "4"]))

    @test !isbinarydata(df)
    @test isbinarydata(dfb)
    @test !isbinarydata(batched_df)
    @test isbinarydata(batched_dfb)

    @test num_examples(shuffle_examples(df)) == 3
    @test 1.1 in feature_values(shuffle_examples(df), 1) 
    
    dft, _, _ = threshold(df, nothing, nothing)

    @test feature_values(dft,1) == [false, false, true]

    @test LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=1) ≈ -1.280557674335465 #not verified
    @test LogicCircuits.Utils.fully_factorized_log_likelihood(dfb) ≈ -1.2730283365896256 #not verified

    @test ll_per_example(-12.3, dfb) ≈ -4.1 #not verified

    @test bits_per_pixel(-12.3, dfb) ≈ 2.9575248338223754 #not verified
    
    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    weights = DataFrame(weight = [0.6, 0.6, 0.6])
    wdfb = hcat(dfb, weights)
    
    @test isweighted(wdfb)
    @test !isweighted(dfb)

end

