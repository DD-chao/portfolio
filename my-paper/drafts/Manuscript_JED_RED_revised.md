# A data-driven satisficing framework for ergonomic product design: surrogate-assisted multi-objective optimization with application to office chair adjustment

Min Qu, Chaoran Deng, Ruiwen Qi*

Contact information: School of Architecture and Design, Nanchang University, Nanchang, Jiangxi, China.

*Corresponding author: qiruiwen@ncu.edu.cn

---

## Abstract

**Engineering design problems frequently involve competing objectives that cannot be simultaneously optimized, requiring designers to navigate trade-offs between quantitative performance metrics and qualitative user experience criteria. In ergonomic product design, this tension is particularly acute: configurations that satisfy subjective comfort do not necessarily minimize objective biomechanical risk, and vice versa. This study presents a data-driven satisficing framework that formalizes this tension as a constrained multi-objective optimization problem, using office chair adjustment as an instantiation. In a controlled laboratory study, 100 participants completed chair-adjustment trials (190 valid samples). A two-stage Random Forest surrogate model was trained to predict seated posture angles from anthropometric and chair-parameter inputs, then to estimate the probability of low postural risk (RULA ≤ 3) and acceptable comfort (Comfort ≥ 7). Generalization was assessed via nested subject-grouped cross-validation (Risk AUC = 0.696, 95% CI [0.623, 0.769]; Comfort AUC = 0.668 [0.491, 0.845]). Under a comfort-satisficing, health-first decision strategy, NSGA-II was employed to identify chair parameter configurations that maximize low-risk probability subject to a comfort feasibility constraint (P(Comfort ≥ 7) ≥ 0.80). The optimized configuration reduced L4/L5 compression (6.6%), AP shear (39.6%), and trunk flexion moment (13.1%) in JACK biomechanical simulation. Critically, feature importance analysis revealed a functional division among design parameters: global structural parameters (seat height, backrest angle) primarily govern objective risk, whereas local support parameters (headrest, armrest) primarily govern subjective comfort. This finding yields a transferable design heuristic—prioritize global structural parameters for safety assurance, then refine local parameters for user experience—that is applicable across a range of adjustable seating products. The proposed framework contributes a closed-loop, evidence-grounded methodology for balancing competing ergonomic objectives in engineering design.**

**Keywords**: Engineering design; Surrogate-assisted optimization; NSGA-II; Satisficing; Random Forest; Ergonomic chair; RULA; Design knowledge

---

## 1. Introduction

**Engineering design is fundamentally a decision-making process under competing objectives, constraints, and uncertainty (Simon, 1956; Pahl, Beitz, Feldhusen, & Grote, 2007). In many design domains, objectives cannot be simultaneously maximized—improving one metric often degrades another—requiring designers to identify acceptable trade-offs rather than theoretical optima. The question of when to optimize and when to satisfice is a foundational concern in design methodology (Guo, Allen, & Mistree, 2024). This tension is particularly pronounced in the design of ergonomic products, where quantitative biomechanical safety metrics and qualitative user experience criteria frequently conflict.**

**The office chair is a representative case of this broader design challenge.** Office employees reportedly spend approximately 80% of working hours seated (Clemes, O'Connell, & Edwardson, 2014), and sedentary behavior has been associated with musculoskeletal disorders, cardiovascular disease, and diabetes (Triglav et al., 2019). Consequently, the optimization of office chairs has gained attention for its potential to simultaneously promote comfort and health. However, a persistent difficulty has been identified in the literature: **objective biomechanical improvements achieved through design may not align with users' subjective comfort reports (De Carvalho & Callaghan, 2022; Helander, 2010; Frey, Barrett, & De Carvalho, 2021). This comfort–risk discrepancy represents a specific instance of a general design problem—how should designers proceed when empirical evidence shows that quality attributes (comfort) and safety attributes (risk) are driven by different subsets of design variables?**

**Prior research has addressed aspects of this problem through two largely disconnected streams. In the ergonomics literature, multi-objective evolutionary algorithms have been applied to balance productivity and worker health (Nourmohammadi, Ng, Fathi, Vollebregt, & Hanson, 2023; Giridhar & Panicker, 2024). Simultaneously, in the design methodology literature, formal frameworks have been developed for managing multi-goal design problems with satisficing strategies (Guo, Milisavljevic-Syed, Wang, Huang, Allen, & Mistree, 2023; Guo et al., 2024). However, these streams rarely intersect: ergonomics studies typically prioritize domain-specific validation over generalizable design knowledge, while design methodology studies often rely on numerical or analytical examples rather than empirically grounded user data.** Machine learning (ML) has emerged as a bridge, with applications in posture recognition, risk assessment, and ergonomic evaluation (Çakit & Karwowski, 2025; Hu, Yan, Wan, Peng, & Qi, 2024). Yet much of this work focuses on posture classification or risk scoring, rather than **using ML surrogate models within a formalized satisficing framework to generate actionable, empirically validated parameter recommendations, and then extracting design knowledge that transfers beyond the specific product domain.**

To address these gaps, **we propose a data-driven satisficing framework that integrates posture assessment, machine-learning surrogate modeling, constraint-based multi-objective optimization, and independent biomechanical validation. The framework is instantiated on office chair adjustment but is designed for generalization to other ergonomic products in bounded design spaces. The core design philosophy is comfort-satisficing, health-first: comfort is treated as a feasibility constraint (satisficing criterion), while postural risk is rigorously minimized within the feasible region.** The main contributions are as follows:

**(1) Satisficing-driven constrained optimization for ergonomic design:** Drawing on Simon's satisficing principle (Simon, 1956) and its recent formalization in engineering design (Guo et al., 2024), we formulate personalized product parameter adjustment as a constrained decision problem, where subjective user experience is treated as a satisficing criterion and objective safety risk is explicitly minimized. This formulation provides a structured, theoretically grounded decision framework that is distinct from conventional weighted-sum Pareto approaches.

**(2) Data-driven surrogate-assisted parameter recommendation:** A two-stage Random Forest surrogate model is trained on empirical user data and coupled with NSGA-II to efficiently explore a bounded design space. The two-stage architecture—predicting interpretable posture angles as intermediate variables before estimating risk and comfort probabilities—improves transparency and aligns with design reasoning.

**(3) Transferable design knowledge: global vs. local parameter roles:** The results reveal a functional division among design variables—global structural parameters (seat height, backrest angle) primarily govern objective risk, while local support parameters (headrest height, armrest height) primarily govern subjective comfort. **This finding yields a transferable design heuristic that can inform the design of other adjustable seating products (e.g., vehicle seats, aircraft seats, wheelchairs) and contributes empirically grounded design knowledge to the engineering design literature.**

**(4) Closed-loop validation chain:** The optimized configurations are independently evaluated using JACK digital human simulation, providing biomechanical evidence (L4/L5 compression, shear, trunk moment) that corroborates the surrogate-based recommendations. This closes the loop from empirical data → surrogate modeling → optimization → independent verification.

The overall workflow is illustrated in Fig. 1. The remainder of this paper is organized as follows. Section 2 reviews related work across three themes: chair design and the comfort–risk gap, posture risk assessment, and **design optimization under competing objectives**. Section 3 presents the proposed framework and methodological details. Section 4 describes the experimental design, surrogate modeling results, optimization outcomes, and JACK-based biomechanical validation. Section 5 discusses **implications for engineering design methodology, the transferability of the identified design heuristic, and** limitations. Section 6 concludes the paper.

---

## 2. Literature Review

### 2.1 Chair Design and the Comfort–Risk Gap

Regarding health risks associated with prolonged sitting, prior work has examined how key office-chair parameters influence spinal loading and posture from a biomechanical perspective. Huang, Hajizadeh, Gibson, and Lee (2016) used biomechanical modeling to show that the effect of backrest angle on lumbar compressive forces depends on multiple interacting factors; specifically, moderate seat depth combined with an appropriate backrest height can help reduce lumbar loading. Using in vivo implant measurements, Rohlmann, Zander, Graichen, Dreischarf, and Bergmann (2011) reported that trunk flexion substantially increases spinal load, whereas moderate trunk extension and larger backrest angles reduce loading.

In contrast, comfortable sitting is not characterized by a single "optimal" posture and shows substantial inter-individual variability. Chen, Chan, and Zhang (2021) observed considerable postural variability as individuals searched for their most comfortable sitting positions. Related evidence also suggests that the relationship between perceived comfort and postural activity is non-linear and task-dependent (Chen et al., 2021; Vergara & Page, 2002). Taken together, chair configurations that appear biomechanically favorable may not be perceived as more comfortable, underscoring a persistent comfort–risk mismatch. **This mismatch is not unique to chair design; it represents a general class of engineering design problems where quantitative performance and qualitative user experience are driven by distinct variable subsets, which this study aims to characterize and resolve through a formal satisficing framework.**

### 2.2 Posture Risk Assessment

Incorporating health risk into decision-making frameworks requires reliable and task-appropriate posture risk metrics. Varghese, V, and George (2025) compared four observational assessment tools—OWAS, RULA, REBA, and PERA—and reported that RULA was the most suitable for evaluating postural load in rubber tapping. RULA has been widely applied for rapid screening in diverse contexts, including sewing-machine operators (Öztürk & Esin, 2011), smartphone-use postures (Namwongsa, Puntumetakul, Neubert, Chaiklieng, & Boucaut, 2018), and dental workstations (Holzgreve et al., 2025). Tahernejad et al. (2022) further combined a posture recording/classification approach with RULA to address the limitations of conventional office ergonomics.

Collectively, these studies support the practical utility of RULA across multiple application scenarios. However, for large-sample studies of everyday office sitting, RULA scoring often relies either on manual observation or on specialized measurement systems. Manual scoring is time-consuming and susceptible to inter-rater variability, whereas instrumented approaches can be costly and operationally burdensome, limiting scalability and personalization. To address these constraints, the present study leverages computer vision to extract sagittal-plane joint angles from lateral images and to compute RULA scores in a semi-automated pipeline. This approach improves efficiency and consistency and provides objective labels for subsequent data-driven modeling and optimization.

### 2.3 Data-driven Ergonomic Modeling and Multi-objective Design Optimization

In recent years, ML has been increasingly adopted in ergonomics, particularly for posture recognition, risk assessment, and the prediction of related biomechanical or physiological metrics. Çakit and Karwowski (2025) reviewed 130 publications (2015–2024) on ML in human factors and ergonomics and reported a marked growth in ML adoption after 2019. ML-based approaches have also been integrated with physiological sensing to support ergonomic evaluation (Mudiyanselage, Nguyen, Rajabi, & Akhavian, 2021; Baklouti et al., 2024). Beyond risk scoring, Xu and Chen (2025) combined the PLEASURC multidimensional evaluation framework with explainable-ML techniques. Farhani, Zhou, Danielson, and Trejos (2022) demonstrated that combining multiple ML models can accurately classify postures during dynamic seating.

For engineering design problems with conflicting objectives, multi-objective optimization is commonly used to generate Pareto-optimal solution sets to support design selection. Nourmohammadi et al. (2023) combined digital human modeling with REBA to develop E-NSGA-II for jointly optimizing cycle time and ergonomic risk. Giridhar and Panicker (2024) similarly applied NSGA-II and related approaches to assembly-line balancing with ergonomics considerations.

**Despite these advances, two limitations remain. First, many ML applications emphasize risk identification, posture classification, or single-metric prediction, but do not explicitly map model outputs to adjustable design variables in a way that yields actionable parameter recommendations grounded in design theory. Second, multi-objective optimization studies in ergonomics often focus on system-level trade-offs (e.g., productivity vs. risk) rather than establishing a closed-loop pipeline—from data-driven modeling to parameter optimization to independent validation—and extracting transferable design knowledge from the optimization results. In particular, there is limited work that explicitly adopts a satisficing philosophy (Simon, 1956; Guo et al., 2024) in data-driven ergonomic optimization, where subjective outcomes with inherently high predictive uncertainty are treated as feasibility constraints rather than optimization targets.**

### 2.4 Optimize or Satisfice in Engineering Design

**The distinction between optimizing and satisficing has been a foundational concern in design methodology since Simon's (1956) articulation of bounded rationality. In engineering design, Guo et al. (2024) formalized this distinction, proposing that designers should explicitly decide whether to optimize or satisfice based on problem characteristics, and developed the compromise Decision Support Problem (cDSP) framework with adaptive linear programming for satisficing under nonlinear constraints. Guo et al. (2023) further proposed the Adaptive Leveling-Weighting-Clustering (ALWC) algorithm for managing multi-goal design problems, demonstrating that structured satisficing strategies can reduce computational burden while preserving solution quality.**

**The present study contributes to this line of inquiry by providing an empirical, data-driven instantiation of the satisficing philosophy in ergonomic product design. Unlike Guo et al. (2024), who focus on analytical and numerical examples, our framework is grounded in experimental data from 100 human participants. Unlike conventional ergonomic optimization studies that treat both comfort and risk as maximization/minimization objectives with arbitrary weights, our comfort-satisficing, health-first strategy provides a theoretically motivated rationale for the constraint structure: comfort, as a subjective construct with inherently high measurement noise and predictive uncertainty, is treated as a satisficing criterion; risk, as a more objectively measurable and predictively stable construct, is treated as the primary optimization target. This integration of design theory (satisficing) with data-driven methods (RF surrogate + NSGA-II) represents a methodological contribution that extends both the design methodology and ergonomics literatures.**

---

## 3. Methods

### 3.1 Overall Framework

**The proposed framework consists of four interconnected stages: (1) empirical data acquisition, where human participants provide anthropometric measurements, posture images, and subjective comfort ratings under varied chair configurations; (2) two-stage surrogate modeling, where RF models learn the mapping from design variables to ergonomic outcomes; (3) satisficing-driven multi-objective optimization, where NSGA-II searches the bounded design space under a comfort-feasibility constraint; and (4) independent biomechanical validation via digital human simulation. Each stage is designed to be domain-adaptable: the chair-specific elements (RULA scoring, six chair parameters) can be substituted with domain-appropriate metrics and variables for other ergonomic products. The workflow is illustrated in Fig. 1.**

### 3.2 RULA Operationalization

RULA enables rapid screening of postural risk by evaluating neck, trunk, and upper-limb posture, as well as muscle use and external load factors (McAtamney & Nigel Corlett, 1993). It has been widely used to support workstation evaluation and ergonomic intervention (Zhang, Li, Xu, Zhao, & Gao, 2024). In the RULA procedure, posture is scored in two sections: Group A (upper arm, lower arm, and wrist) and Group B (neck, trunk, and legs). Sub-scores are first computed for each section and then combined into an overall RULA score using standardized lookup tables.

Because the present study focuses on static seated office postures and uses lateral images, RULA scoring primarily depends on sagittal-plane angles of the neck, trunk, and upper limbs. The following operational assumptions were adopted: (1) neck flexion ≥ 0 indicates flexion and neck flexion < 0 indicates extension; trunk flexion ≥ 0 indicates recline and trunk flexion < 0 indicates forward trunk flexion; (2) upper-arm angle is converted to an elevation magnitude relative to the vertical reference; (3) component scores are combined using the official RULA lookup tables; (4) wrist-related items, muscle use, and external load are treated as controlled conditions; (5) foot/leg support is assumed to be present. This operationalization should be interpreted as a sagittal-plane, task-controlled implementation of RULA for standardized comparisons within the seated-office context. The resulting scores are intended for relative risk ranking and optimization within the sampled design space rather than as full multi-planar clinical-grade RULA assessments. Detailed scoring rules are provided in Table 1.

### 3.3 Computer Vision-enabled RULA Scoring

A semi-automated posture assessment workflow was implemented to address the limitations of manual RULA scoring. Stable and visually identifiable anatomical landmarks are manually annotated on lateral seated images; the resulting 2D coordinates are used to compute joint angles under a sagittal-plane approximation, and these angles are mapped to RULA scores using standardized decision rules. The workflow is summarized in Fig. 2.

The nine annotated landmarks are: outer canthus, tragus, acromion, elbow, wrist, palm, greater trochanter, knee, and ankle. These landmarks were used to construct segment vectors and compute sagittal-plane posture angles (neck, trunk, upper arm, elbow, and knee), as illustrated in Fig. 3. Angle computation uses the inverse tangent function (atan2d) with the vertical upward direction as the unified reference, ensuring stable quadrant determination. Image-based posture analysis is sensitive to recording conditions (Plantard, Shum, Le Pierres, & Multon, 2017). To reduce information loss, the camera setup was standardized: a high-definition camera mounted on a tripod 3.0 m to the right of the chair, with the optical axis aligned to the approximate horizontal midline of the seated trunk and kept perpendicular to the participant's sagittal plane. The defined angles, vector construction rules, and unified notation conventions provide a reproducible computational process for subsequent RULA sub-score mapping.

### 3.4 Two-Stage Random Forest Surrogate Model

Random Forests (RF) aggregate multiple decision trees and are widely used due to strong predictive performance, robustness to noise and outliers, and effective handling of high-dimensional features (Breiman, 2001). Because both posture-related risk and perceived comfort are strongly mediated by sitting posture, a direct mapping from anthropometrics and chair parameters to risk/comfort can be sensitive to inter-individual variability and measurement noise. We therefore adopt a two-stage surrogate modeling strategy:

**Stage 1 — Postural-angle prediction.** Anthropometric variables (6) and chair parameters (6) serve as inputs, and the five joint angles computed from the image-annotation workflow serve as supervised labels. An RF regressor predicts key sagittal-plane angles, yielding a predicted posture vector. **These predicted angles serve as interpretable intermediate variables—a design choice motivated by the principle that surrogate models in engineering design should preserve physically meaningful intermediate representations where possible.**

**Stage 2 — Risk and comfort surrogates.** The predicted posture vector is concatenated with standardized input features to form an augmented feature set. An RF classifier outputs two probabilistic scores: P(RULA ≤ 3) — the low-risk probability, and P(Comfort ≥ 7) — the comfort-satisfied probability. These probabilities are used to construct the objective function and constraint for NSGA-II.

The overall feature set and prediction targets are summarized in Table 2. All input features are standardized using Z-score normalization, where the mean and standard deviation are estimated from the training set and reused during optimization.

**Generalization is assessed using nested subject-grouped cross-validation to avoid information leakage across participants and to provide an honest estimate of model performance on unseen individuals. ROC–AUC is the primary metric for the binary classification tasks, summarized as the mean with 95% confidence interval across outer folds. For the postural-angle regression task, mean absolute error (MAE, degrees) is reported. To prevent leakage in the two-stage pipeline, stage-1 posture predictors are trained only on training subjects of a given split, and posture features for test subjects are generated strictly as out-of-fold predictions. Hyperparameter tuning is performed via random search exclusively within the inner loop of the nested cross-validation.**

### 3.5 Satisficing-Driven Multi-objective Optimization with NSGA-II

**The decision strategy of this framework is grounded in the satisficing principle (Simon, 1956; Guo et al., 2024): when objectives have heterogeneous predictability and measurement quality, the less reliable objective (comfort) should be treated as a feasibility constraint, while the more reliable objective (risk) is optimized within the feasible region. This is operationalized as follows.**

Let the six adjustable chair parameters define the decision vector **x**. Given a target user with anthropometric features, the two-stage surrogate outputs P_lowRisk(**x**) and P_highComfort(**x**). Considering the inherent variability and subjectivity in comfort ratings, and the relatively lower predictive stability observed for comfort (see Section 4.3), comfort is treated as a satisficing constraint with threshold *α* = 0.80. The constrained optimization problem is formulated as:

$$\max_{\mathbf{x}} \; P_{lowRisk}(\mathbf{x}) \quad \text{s.t.} \quad P_{highComfort}(\mathbf{x}) \geq \alpha$$

For computational implementation, violations of the comfort constraint are penalized:

$$\min_{\mathbf{x}} \; \mathbf{f}(\mathbf{x}) = \left[-P_{lowRisk}(\mathbf{x}),\; \lambda \cdot \max(0, \alpha - P_{highComfort}(\mathbf{x}))^2\right]$$

where λ = 50 is a penalty weight. NSGA-II (Deb, Pratap, Agarwal, & Meyarivan, 2002) is employed with a population size of 150 and 80 generations. The final recommendation **x*** is selected by (i) identifying solutions satisfying P_highComfort ≥ 0.80, and (ii) choosing the solution with the largest P_lowRisk within that feasible set.

**This formulation has two distinguishing features relative to conventional multi-objective chair optimization. First, it avoids the arbitrariness of weighted-sum scalarization by providing a theoretically motivated rationale for the constraint structure. Second, by embedding the satisficing decision directly into the optimization formulation, the framework produces a single actionable recommendation rather than a Pareto frontier requiring post-hoc designer judgment—an advantage for deployment in practical design contexts.**

The recommended parameters are subsequently evaluated using JACK digital human simulation (Section 4.5).

---

## 4. Experiment and Results

### 4.1 Experiment Setup and Data

Standardized data collection was conducted in a controlled laboratory environment. A high-end ergonomic office chair with independent six-dimensional adjustability was used. The adjustable ranges, which define the search-space bounds for optimization, are provided in Table 3.

A total of 100 healthy adults were recruited (41 males, 59 females; aged 20–50 years; office workers or university students with long-term desk-based work experience). The study was approved by the Research Ethics Committee of Nanchang University and conducted in accordance with the Declaration of Helsinki. Written informed consent was obtained from all participants.

The experiment followed a within-subject design with two phases. **Phase 1 (Self-adjustment):** Participants adjusted the chair to their most comfortable configuration. After maintaining the posture for 10 min, seat parameters were recorded, lateral-view images were captured, and subjective comfort was assessed on a 9-point Likert scale (1 = extremely uncomfortable, 9 = very comfortable). **Phase 2 (Controlled perturbation):** To improve coverage of the adjustable parameter space and enhance surrogate model discriminability, the initial configurations were systematically perturbed within the allowable adjustment ranges using random magnitude combinations. Participants passively accepted the perturbed configurations and maintained posture for 10 min under the same controlled conditions. The same recording procedure was then performed.

This two-phase design captured both preferred (high-comfort) and non-preferred configurations, supporting robust model training and reliable exploration of the comfort–risk trade-off space. Overall, 200 samples were collected; after data cleaning and quality control, 190 valid samples were retained. The final dataset comprises three components: (1) 12 input features (6 anthropometric + 6 chair-setting variables); (2) output labels (comfort ratings and RULA scores); and (3) preprocessing (Z-score normalization with parameters estimated from training folds only).

### 4.2 Descriptive Statistics and Comfort–Risk Distribution

Anthropometric characteristics of the participants are reported in Table 4. The relatively large standard deviations across several measures indicate substantial anthropometric variability.

The distributions of objective postural risk and subjective comfort (Fig. 4) reveal a **systematic comfort–risk discrepancy** that constitutes the primary empirical motivation for the satisficing framework. Most RULA scores clustered around 4, indicating that typical office sitting postures often fall within a range where ergonomic intervention may be warranted; only a small proportion of trials achieved low-risk scores of 1–2. In contrast, comfort ratings were frequently high (7–9 range). **Participants often reported high comfort while adopting postures associated with elevated RULA-based risk. This evidence demonstrates that subjective comfort alone is an incomplete design criterion and empirically reinforces the satisficing design philosophy: when comfort and risk are weakly correlated or driven by different design variables, treating comfort as an optimization target may inadvertently lead to high-risk configurations.**

### 4.3 Performance of Surrogate Models

To enable efficient exploration of the seat-parameter space with NSGA-II, we developed two-stage surrogate models. Model selection compared Random Forest (RF), Support Vector Machines (SVM), and Logistic Regression using subject-grouped out-of-fold (OOF) predictions after hyperparameter tuning. As shown in Fig. 5, RF achieved the best performance for both tasks (Risk AUC = 0.714; Comfort AUC = 0.610), outperforming Logistic Regression (Risk AUC = 0.612; Comfort AUC = 0.581) and SVM (Risk AUC = 0.467; Comfort AUC = 0.384). RF was therefore selected as the surrogate for NSGA-II optimization.

Generalization performance was evaluated using nested subject-grouped cross-validation (Table 5). **Risk prediction showed stable cross-subject discriminative performance (AUC = 0.696, 95% CI [0.623, 0.769]), supporting its use as the primary optimization target. Comfort prediction showed moderate discrimination on average but with wide confidence intervals (AUC = 0.668, 95% CI [0.491, 0.845]), indicating greater cross-subject uncertainty for subjective outcomes. This asymmetric predictive reliability provides an empirical justification for the comfort-satisficing, health-first strategy: maximizing an unreliable comfort predictor may produce overfitted or unstable recommendations, whereas using it as a feasibility filter and optimizing the more stable risk predictor yields a more robust decision framework. The engineering goal is not to precisely regress each individual's comfort score, but to determine whether a candidate configuration satisfies an acceptable comfort range.**

#### Table 5. Generalization performance under nested subject-grouped CV (outer K = 5)

| Task | Definition | Metric | Mean | SD | 95% CI |
|------|-----------|--------|------|-----|--------|
| Risk classification | Low risk if RULA ≤ 3 | AUC | 0.696 | 0.059 | [0.623, 0.769] |
| Comfort classification | High comfort if Comfort ≥ 7 | AUC | 0.668 | 0.143 | [0.491, 0.845] |

### 4.4 Feature Importance: Global vs. Local Parameter Roles

**The relative importance of the six adjustable chair parameters for predicting risk and comfort, after controlling for individual-specific characteristics, revealed a functional division among design variables (Fig. 6)—a finding that constitutes the primary transferable design knowledge contribution of this study.**

**In the comfort model, headrest height and armrest height showed higher relative importance, indicating that perceived comfort is more strongly influenced by localized support features that provide immediate tactile and proprioceptive feedback. In the risk model, seat height and backrest angle were more influential, indicating that global seating geometry—which shapes overall trunk posture and spinal loading—plays a more critical role in postural risk. Notably, backrest angle exhibited relatively low importance for comfort but high importance for risk, implying that users may not readily perceive the biomechanical consequences of backrest configuration. This perceptual blind spot can create a latent risk condition where high comfort co-occurs with elevated biomechanical risk.**

**From a design methodology perspective, this finding yields a transferable design heuristic:**

> **Global structural parameters should be configured first to ensure biomechanical safety; local support parameters should then be refined to enhance perceived comfort.**

**This staged design strategy has several advantages: (1) it decomposes a complex multi-objective problem into a sequential procedure aligned with the natural hierarchy of design variables; (2) it prevents the common failure mode where subjective feedback overemphasizes immediately noticeable local features at the expense of structural safety; and (3) it is independent of the specific product domain—the global/local distinction applies to any adjustable ergonomic product where some parameters govern overall posture and others govern localized support (e.g., vehicle seats, aircraft seats, wheelchairs, dental chairs).**

### 4.5 Multi-objective Optimization Results

To evaluate the effectiveness of the proposed framework, a case study was conducted using a representative male participant (175 cm, 70 kg; Table 6). The trained two-stage RF surrogate and NSGA-II were used to search the chair-parameter space defined in Table 3.

The distribution of NSGA-II candidate solutions and the selected recommendation are shown in Fig. 7. The horizontal dashed line denotes the comfort-feasibility threshold (α = 0.80), and the red asterisk indicates the recommended solution—the configuration with the highest predicted low-risk probability within the comfort-feasible region. For this configuration, the surrogate predicts P_lowRisk ≈ 0.8+ and P_highComfort ≥ 0.80.

Table 7 compares the optimized parameters with the mean chair settings across all trials. **The optimized configuration suggests consistent adjustment directions: notably, seat height was reduced from the dataset mean of 49.8 cm to 43.6 cm, and headrest height from 61.7 cm to 55.2 cm, while backrest angle remained relatively stable (113° vs. 114.1°). These adjustments are consistent with the global/local parameter distinction: the largest changes occurred in global structural parameters (seat height) that govern overall posture and risk, while local support parameters showed more moderate shifts. The comparison also suggests that unguided, preference-based adjustments alone may not reliably produce low-risk sitting postures, supporting the value of satisficing-driven optimization as a corrective design tool.**

### 4.6 Validation with JACK Biomechanical Simulation

To evaluate the biomechanical plausibility of the recommended configurations, comparative simulations were performed in Siemens JACK ForceSolver for baseline (pre-optimization mean) and optimized designs. A digital human model (male, 175 cm, 70 kg) was created with standardized conditions: zero external loads, identical ForceSolver sitting-support strategy, 9-h workday assumption, and JACK's standard sitting template with minimal posture adjustments. Under these controls, outcome differences primarily reflect mechanical changes attributable to chair-parameter variations.

Table 8 summarizes the biomechanical indicators. Relative to baseline, the optimized configuration showed consistent reductions: L4/L5 compression decreased by 6.6% (740.9 N → 691.8 N); L4/L5 AP shear decreased by 39.6% (27.3 N → 16.5 N); and trunk flexion moment decreased by 13.1% (41.1 Nm → 35.7 Nm). **Critically, the contribution of these findings lies not in the absolute magnitude of individual reductions, but in the consistent improvement across multiple biomechanical metrics—compression, shear, and moment all moved in the favorable direction. This pattern coherence provides convergent evidence that the satisficing-driven optimization framework identifies configurations with genuine biomechanical benefits, rather than overfitting to surrogate-model artifacts.**

---

## 5. Discussion

### 5.1 The Comfort–Risk Discrepancy as a Design Problem

**The empirical results of this study document a systematic comfort–risk discrepancy in office chair adjustment: configurations rated as highly comfortable were frequently associated with elevated postural risk. This finding is consistent with prior observations in the ergonomics literature (Carcone & Keir, 2007; Helander, 2010), but we interpret it through a design methodology lens. The discrepancy is not merely an empirical curiosity—it is a structural feature of the design problem that arises when subjective quality attributes and objective safety attributes are governed by largely non-overlapping subsets of design variables.**

**This structural interpretation distinguishes our contribution from prior work. Rather than treating the comfort–risk discrepancy as a measurement challenge to be overcome through better instrumentation, we treat it as a design constraint that should be explicitly addressed through the optimization formulation. The comfort-satisficing, health-first strategy is a direct response to this structural feature: by embedding comfort as a feasibility constraint rather than an optimization target, the framework acknowledges the asymmetric reliability of the two surrogate models while still ensuring that comfort requirements are met.**

### 5.2 Satisficing as a Design Philosophy for Data-Driven Optimization

**The proposed framework instantiates Simon's (1956) satisficing principle within a data-driven optimization context. Guo et al. (2024) recently formalized the optimize-vs-satisfice choice in engineering design using analytical methods; our study extends this line of inquiry by providing an empirical counterpart grounded in human subject data. The asymmetric predictive reliability of the two surrogate models—Risk AUC 0.696 with tight CI [0.623, 0.769] vs. Comfort AUC 0.668 with wide CI [0.491, 0.845]—provides a data-driven justification for the satisficing formulation that complements the theoretical arguments advanced by Guo et al. (2024).**

**A practical implication for design methodology is that the choice between optimizing and satisficing need not be made a priori on purely theoretical grounds; it can be informed by empirical evidence about the predictive reliability of surrogate models for different design objectives. When surrogate models exhibit substantially asymmetric reliability—as is common when modeling subjective user experience alongside objective physical metrics—a satisficing constraint structure may be the more robust choice.**

### 5.3 Transferable Design Knowledge: The Global–Local Parameter Heuristic

**The most significant contribution of this study from a design knowledge perspective is the identification of a functional division among design parameters. Feature importance analysis revealed that global structural parameters (seat height, backrest angle) are the primary drivers of objective postural risk, while local support parameters (headrest height, armrest height) are the primary drivers of subjective comfort. This finding has both explanatory and prescriptive value.**

**Explanatorily, it provides a variable-level mechanism for the comfort–risk discrepancy: users' comfort judgments are dominated by immediately perceptible local support features, while risk-relevant global structural features may escape conscious awareness. Consequently, designs driven by subjective feedback alone may converge on configurations with well-tuned local support but suboptimal global structure—precisely the high-comfort, high-risk pattern observed in our data.**

**Prescriptively, it yields a staged design strategy applicable across adjustable ergonomic products:**

1. **Stage A — Global risk control:** Configure global structural parameters (e.g., seat height, backrest angle, seat depth) to achieve biomechanically safe postures. These parameters should be optimized with respect to objective risk metrics, as they are the primary risk drivers and users have limited perceptual sensitivity to their effects.
2. **Stage B — Local comfort refinement:** Within the safety-constrained design space established in Stage A, refine local support parameters (e.g., headrest height, armrest height, lumbar support position) to enhance subjective comfort.

**This heuristic is transferable to other bounded-design-space ergonomic products—vehicle seats, aircraft seats, wheelchairs, dental chairs—where analogous global/local parameter distinctions can be identified. The underlying principle is domain-independent: when design variables can be partitioned by their relative influence on objective safety vs. subjective experience, a staged optimization strategy that prioritizes safety-critical parameters may be more robust than simultaneous multi-objective optimization.**

### 5.4 Closed-Loop Validation and Practical Implications

**The JACK simulation results provide independent biomechanical evidence that corroborates the surrogate-based recommendations. The consistent reductions across L4/L5 compression, AP shear, and trunk flexion moment suggest coherent biomechanical benefits rather than isolated improvements that may reflect surrogate overfitting. This closed-loop architecture—empirical data → surrogate modeling → optimization → independent simulation verification—strengthens the evidence chain and distinguishes the framework from optimization-only approaches that lack independent validation.**

**From a practical engineering design perspective, the framework supports two distinct use cases: (1) personalized adjustment guidance, where the framework recommends chair parameters for an individual user given their anthropometric profile; and (2) population-level design, where the framework can be applied across anthropometric percentiles to inform the specification of adjustable ranges for mass-produced ergonomic products. The global–local parameter heuristic further supports design communication: it provides a concise, evidence-based rationale for why certain design decisions should be prioritized, facilitating alignment among designers, ergonomists, and stakeholders.**

### 5.5 Limitations and Future Work

Several limitations should be noted. First, the study focuses on short-term seated postures (10 min per configuration) and does not account for fatigue accumulation or posture variation over prolonged exposure. **Extended-duration studies with repeated measurements would strengthen the generalizability of the identified design heuristic to real-world usage contexts.** Second, the JACK-based verification is quasi-static and cannot fully capture dynamic behaviors or inter-individual differences in muscle activation patterns. **Future work should incorporate dynamic simulations and, where feasible, in vivo validation using electromyography or pressure distribution measurement.** Third, the surrogate model is constrained by the sampled design space (Table 3) and is primarily intended for optimization and relative ranking within that space. Generalizability across populations and task contexts requires further validation. Fourth, comfort assessment used a single-item 9-point scale, which captures global perceived comfort efficiently but does not provide localized comfort information that could further refine the global–local parameter heuristic. **Multi-dimensional comfort assessment instruments could enable more granular mapping between specific design parameters and specific comfort dimensions.**

**Future work will extend the framework in four directions. First, broader and more diverse populations will be included to assess the robustness of the global–local parameter heuristic across sex, body types, and anthropometric percentiles. Second, the framework will be applied to additional ergonomic products (e.g., vehicle seats, wheelchairs) to test the transferability of the design heuristic and to identify domain-specific boundary conditions. Third, the staged design strategy will be formalized into a sequential optimization procedure and compared against simultaneous multi-objective approaches in terms of solution quality, computational efficiency, and designer interpretability. Fourth, interactive decision-support tools based on the framework will be developed and evaluated through user studies with professional designers, to assess whether the satisficing formulation and global–local heuristic improve design decision quality in practice.**

---

## 6. Conclusions

**This study proposed and validated a data-driven satisficing framework that integrates two-stage Random Forest surrogate modeling, NSGA-II multi-objective optimization, and JACK biomechanical simulation for ergonomic product design, instantiated on office chair adjustment. The framework is grounded in the satisficing design philosophy (Simon, 1956; Guo et al., 2024): comfort is treated as a feasibility constraint, while postural risk is minimized within the feasible region. This formulation is empirically justified by the asymmetric predictive reliability of the two surrogate models and provides a structured, reproducible alternative to conventional weighted-sum Pareto approaches.**

**The primary design knowledge contribution is the identification of a functional division among design parameters. Global structural parameters (seat height, backrest angle) primarily govern objective postural risk; local support parameters (headrest height, armrest height) primarily govern subjective comfort. This finding yields a transferable design heuristic—prioritize global structural adjustments for safety, then refine local support for comfort—that is applicable across a range of adjustable ergonomic products. JACK simulation provided independent biomechanical corroboration, with consistent reductions in L4/L5 compression (6.6%), AP shear (39.6%), and trunk flexion moment (13.1%).**

**Overall, the proposed framework contributes a closed-loop, evidence-grounded methodology for balancing competing ergonomic objectives within bounded design spaces. The integration of design theory (satisficing), data-driven methods (RF surrogate), multi-objective optimization (NSGA-II), and independent validation (JACK) establishes a methodological template that can be adapted to other ergonomic product domains where subjective and objective design criteria must be jointly satisfied.**

---

## Acknowledgements

This research is supported by Jiangxi Provincial Housing and Urban-Rural Construction Science and Technology Project Plan: Research on the Design of Modular Age-Friendly Outdoor Furniture Systems for Old Communities in Nanchang Aimed at "Four Good" Construction (Grant No. 20251KYSH719).

## Use of Generative AI

To ensure transparency, the authors state that ChatGPT (OpenAI) was used only for English translation and language polishing, while all research design, data analysis, and conclusions are the independent work of the authors.

## Author Contributions

Min Qu conceived and designed the study, and revised the manuscript.
Chaoran Deng developed the methodology, conducted the experiments, analyzed the data, and drafted the manuscript.
Ruiwen Qi supervised the project, provided resources and funding, and managed the project administration.
All authors have read and approved the final manuscript.

---

## References

Baklouti, S., Rezgui, T., Chaker, A., Mefteh, S., Ben Mansour, K., Sahbani, A., & Bennour, S. (2024). An Integrated Force Myography and SVM-Based Machine Learning System for Enhanced Muscle Exertion Assessment in Industrial Settings. *Arabian Journal for Science and Engineering*, 50(14), 11019-11032. https://doi.org/10.1007/s13369-024-09138-8

Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5-32. https://doi.org/10.1023/A:1010933404324

Çakit, E., & Karwowski, W. (2025). Applications of Machine Learning in Human Factors and Ergonomics: A Comprehensive Review of Research From the Past Decade. *IEEE Access*, 13, 115263-115288. https://doi.org/10.1109/access.2025.3585773

Carcone, S. M., & Keir, P. J. (2007). Effects of backrest design on biomechanics and comfort during seated work. *Applied Ergonomics*, 38(6), 755-764. https://doi.org/10.1016/j.apergo.2006.11.001

Chen, Y. L., Chan, Y. C., & Zhang, L. P. (2021). Postural Variabilities Associated with the Most Comfortable Sitting Postures: A Preliminary Study. *Healthcare*, 9(12). https://doi.org/10.3390/healthcare9121685

Clemes, S. A., O'Connell, S. E., & Edwardson, C. L. (2014). Office Workers' Objectively Measured Sedentary Behavior and Physical Activity During and Outside Working Hours. *Journal of Occupational & Environmental Medicine*, 56(3), 298-303. https://doi.org/10.1097/jom.0000000000000101

De Carvalho, D. E., & Callaghan, J. P. (2022). Effect of office chair design features on lumbar spine posture, muscle activity and perceived pain during prolonged sitting. *Ergonomics*, 66(10), 1465-1476. https://doi.org/10.1080/00140139.2022.2152113

Deb, K., Pratap, A., Agarwal, S., & Meyarivan, T. (2002). A fast and elitist multiobjective genetic algorithm: NSGA-II. *IEEE Transactions on Evolutionary Computation*, 6(2), 182-197. https://doi.org/10.1109/4235.996017

Farhani, G., Zhou, Y., Danielson, P., & Trejos, A. L. (2022). Implementing Machine Learning Algorithms to Classify Postures and Forecast Motions When Using a Dynamic Chair. *Sensors*, 22(1). https://doi.org/10.3390/s22010400

Frey, M., Barrett, M., & De Carvalho, D. (2021). Effect of a dynamic seat pan design on spine biomechanics, calf circumference and perceived pain during prolonged sitting. *Applied Ergonomics*, 97. https://doi.org/10.1016/j.apergo.2021.103546

Giridhar, M. P., & Panicker, V. V. (2024). Effect of ergonomic aspects on single- and multiproduct assembly-line balancing problems. *Human Factors and Ergonomics in Manufacturing & Service Industries*, 34(6), 491-515. https://doi.org/10.1002/hfm.21046

**Guo, L., Allen, J. K., & Mistree, F. (2024). Optimize or satisfice in engineering design? *Research in Engineering Design*, 35(3), 239-267. https://doi.org/10.1007/s00163-023-00431-5**

**Guo, L., Milisavljevic-Syed, J., Wang, R., Huang, Y., Allen, J. K., & Mistree, F. (2023). Managing multi-goal design problems using adaptive leveling-weighting-clustering algorithm. *Research in Engineering Design*, 34(1), 39-60. https://doi.org/10.1007/s00163-022-00394-z**

Helander, M. G. (2010). Forget about ergonomics in chair design? Focus on aesthetics and comfort! *Ergonomics*, 46(13-14), 1306-1319. https://doi.org/10.1080/00140130310001610847

Holzgreve, F., Preuss, J., Erbe, C., Betz, W., Wanke, E. M., Oremek, G., ... Ohlendorf, D. (2025). The Role of Chair Design in Dental Ergonomics: A Kinematic Assessment of Movement and Ergonomic Risk. *Bioengineering*, 12(4). https://doi.org/10.3390/bioengineering12040353

Hu, X., Yan, H., Wan, C., Peng, L., & Qi, Y. (2024). Online Rapid Job Analysis and Evaluation Using Particle Swarm Optimized Random Forest. *IEEE Access*, 12, 156420-156432. https://doi.org/10.1109/access.2024.3484671

Huang, M., Hajizadeh, K., Gibson, I., & Lee, T. (2016). The Influence of Various Seat Design Parameters: A Computational Analysis. *Human Factors and Ergonomics in Manufacturing & Service Industries*, 26(3), 356-366. https://doi.org/10.1002/hfm.20649

MassirisFernández, M., Fernández, J. Á., Bajo, J. M., & Delrieux, C. A. (2020). Ergonomic risk assessment based on computer vision and machine learning. *Computers & Industrial Engineering*, 149. https://doi.org/10.1016/j.cie.2020.106816

McAtamney, L., & Nigel Corlett, E. (1993). RULA: a survey method for the investigation of work-related upper limb disorders. *Applied Ergonomics*, 24(2), 91-99. https://doi.org/10.1016/0003-6870(93)90080-S

Mudiyanselage, S. E., Nguyen, P. H. D., Rajabi, M. S., & Akhavian, R. (2021). Automated Workers' Ergonomic Risk Assessment in Manual Material Handling Using sEMG Wearable Sensors and Machine Learning. *Electronics*, 10(20). https://doi.org/10.3390/electronics10202558

Namwongsa, S., Puntumetakul, R., Neubert, M. S., Chaiklieng, S., & Boucaut, R. (2018). Ergonomic risk assessment of smartphone users using the Rapid Upper Limb Assessment (RULA) tool. *PLoS One*, 13(8), e0203394. https://doi.org/10.1371/journal.pone.0203394

Nourmohammadi, A., Ng, A. H. C., Fathi, M., Vollebregt, J., & Hanson, L. (2023). Multi-objective optimization of mixed-model assembly lines incorporating musculoskeletal risks assessment using digital human modeling. *CIRP Journal of Manufacturing Science and Technology*, 47, 71-85. https://doi.org/10.1016/j.cirpj.2023.09.002

Öztürk, N., & Esin, M. N. (2011). Investigation of musculoskeletal symptoms and ergonomic risk factors among female sewing machine operators in Turkey. *International Journal of Industrial Ergonomics*, 41(6), 585-591. https://doi.org/10.1016/j.ergon.2011.07.001

**Pahl, G., Beitz, W., Feldhusen, J., & Grote, K. H. (2007). *Engineering Design: A Systematic Approach* (3rd ed.). Springer. https://doi.org/10.1007/978-1-84628-319-2**

Plantard, P., Shum, H. P. H., Le Pierres, A. S., & Multon, F. (2017). Validation of an ergonomic assessment method using Kinect data in real workplace conditions. *Applied Ergonomics*, 65, 562-569. https://doi.org/10.1016/j.apergo.2016.10.015

Rohlmann, A., Zander, T., Graichen, F., Dreischarf, M., & Bergmann, G. (2011). Measured loads on a vertebral body replacement during sitting. *Spine Journal*, 11(9), 870-875. https://doi.org/10.1016/j.spinee.2011.06.017

**Simon, H. A. (1956). Rational choice and the structure of the environment. *Psychological Review*, 63(2), 129-138. https://doi.org/10.1037/h0042769**

Tahernejad, S., Choobineh, A., Razeghi, M., Abdoli-Eramaki, M., Parsaei, H., Daneshmandi, H., & Seif, M. (2022). Investigation of office workers' sitting behaviors in an ergonomically adjusted workstation. *International Journal of Occupational Safety and Ergonomics*, 28(4), 2346-2354. https://doi.org/10.1080/10803548.2021.1990581

Triglav, J., Howe, E., Cheema, J., Dube, B., Fenske, M. J., Strzalkowski, N., & Bent, L. (2019). Physiological and cognitive measures during prolonged sitting: Comparisons between a standard and multi-axial office chair. *Applied Ergonomics*, 78, 176-183. https://doi.org/10.1016/j.apergo.2019.03.002

Varghese, A., V, V. P., & George, J. (2025). Posture Assessment of Rubber Tappers: A Comparative Analysis of OWAS, REBA, RULA, and PERA Methods. *La Medicina del Lavoro*, 116(3), 15875. https://doi.org/10.23749/mdl.v116i3.15875

Vergara, M., & Page, A. (2002). Relationship between comfort and back posture and mobility in sitting-posture. *Applied Ergonomics*, 33(1), 1-8. https://doi.org/10.1016/S0003-6870(01)00056-4

Xu, W., & Chen, Y. (2025). Framework for the Evaluation of Nap-Compatible Classroom Chairs. *Buildings*, 15(18). https://doi.org/10.3390/buildings15183321

Zhang, F., Li, X., Xu, S., Zhao, X., & Gao, Y. (2024). Ergonomic design of safety protective wearables in confined space operations. *Advanced Design Research*, 2(2), 137-150. https://doi.org/10.1016/j.ijadr.2025.01.001
