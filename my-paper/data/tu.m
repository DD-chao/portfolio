graph TD
    %% 定义样式
    classDef phase1 fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef phase2 fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef phase3 fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef phase4 fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    classDef storage fill:#fff,stroke:#333,stroke-dasharray: 5 5;

    %% Phase 1: Data Acquisition
    subgraph P1 [Phase 1: Data Acquisition & Processing]
        direction TB
        Participants[96 Participants\n(Anthropometry)] --> Exp[Experiment:\nSelf-adjust vs. Expert-intervene]
        Exp --> Photos[Image Capture\n(Side-view)]
        Exp --> Rating[Subjective Comfort Rating]
        
        Photos --> MATLAB[MATLAB System]
        MATLAB -->|Computer Vision| Landmarks[Landmark Detection]
        Landmarks -->|Geometric Correction| Angles[Joint Angles Calculation]
        Angles -->|Strict Logic| RULA[RULA Score Calculation]
        
        RULA --> Dataset[(Final Dataset\nN=192)]
        Rating --> Dataset
        Participants --> Dataset
        ChairParams[Chair Parameters] --> Dataset
    end
    class Participants,Exp,Photos,Rating,MATLAB,Landmarks,Angles,RULA,ChairParams phase1;

    %% Phase 2: Modeling
    subgraph P2 [Phase 2: Machine Learning Modeling]
        Dataset --> RF[Random Forest Algorithm]
        RF --> TrainC[Comfort Prediction Model]
        RF --> TrainR[RULA Prediction Model]
        TrainC --> FitCheck{Training Fit\nR2 > 0.85?}
        TrainR --> FitCheck
    end
    class RF,TrainC,TrainR,FitCheck phase2;

    %% Phase 3: Optimization
    subgraph P3 [Phase 3: Multi-Objective Optimization]
        Target[Target User Definition\n(e.g., P50 Male)] --> NSGA[NSGA-II Algorithm]
        Constraint[Design Constraints] --> NSGA
        FitCheck -->|Surrogate Models| NSGA
        
        NSGA --> Pareto[Pareto Optimal Frontier]
        Pareto --> OptParams[Optimal Design Parameters]
    end
    class Target,Constraint,NSGA,Pareto,OptParams phase3;

    %% Phase 4: Validation
    subgraph P4 [Phase 4: JACK Simulation Validation]
        OptParams --> JackOpt[Optimized Scene]
        Baseline[Baseline Scene] --> JackBase[Baseline Simulation]
        JackOpt --> JackSim[JACK Biomechanical Analysis]
        JackBase --> JackSim
        
        JackSim --> Metrics[Metrics Comparison:\n1. L4/L5 Compression\n2. Joint Moments]
        Metrics --> Conclusion[Final Ergonomic Framework]
    end
    class JackOpt,Baseline,JackBase,JackSim,Metrics,Conclusion phase4;

    