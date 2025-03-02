function [G, solInfo] = helperLocalFactorGraphOptimization(G, viewToNode, kfList, fixedViewIds)

    if ~isempty(fixedViewIds)
    fixNode(G, viewToNode(fixedViewIds))
    end

    fgso = factorGraphSolverOptions;
    fgso.MaxIterations = 5;
    fgso.VerbosityLevel = 0;
    fgso.FunctionTolerance  = 1e-5;
    fgso.GradientTolerance = 1e-5;
    fgso.StepTolerance = 1e-5;
    fgso.TrustRegionStrategyType = 1;

    solInfo = optimize(G, viewToNode(kfList), fgso);
    
    if ~isempty(fixedViewIds)
    fixNode(G, viewToNode(fixedViewIds),false)
    end

end