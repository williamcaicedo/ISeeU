# ISeeU: Visually interpretable deep learning for mortality prediction inside the ICU

A ConvNet trained on MIMIC-III data for mortality prediction inside the Intensive Care Unit. It uses a set of 22 predictors sampled during the first 48h of ICU stay to predict the probability of mortality. This set of predictors roughly corresponds to those used by the SAPS-II severity score: 

  - AGE 
  - AIDS 
  - BICARBONATE 
  - BILIRRUBIN 
  - BUN 
  - DIASTOLIC BP 
  - ELECTIVE 
  - FiO2 
  - GCSEyes
  - GCSMotor
  - GCSVerbal
  - HEART RATE
  - LYMPHOMA
  - METASTATIC CANCER
  - PO2
  - POTASSIUM
  - SODIUM
  - SURGICAL
  - SYSTOLIC BP
  - TEMPERATURE
  - URINE OUTPUT
  - WBC

ISeeU achieves 0.8735 AUROC when evaluated on MIMIC-III. More information is available in our ArXiv [preprint](https://arxiv.org/abs/1901.08201). It also can be installed from PyPi:

```unix
pip install iseeu
```

