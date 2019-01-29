from setuptools import setup


def readme():
    with open('README.md') as f:
        return f.read()


setup(
    include_package_data=True,
    name='iseeu',
    packages=['iseeu'],
    version='0.1.2',
    license='MIT',
    description='ISeeU: Visually interpretable deep learning for mortality prediction inside the ICU',
    long_description='''A ConvNet trained on MIMIC-III data for mortality prediction inside the Intensive Care Unit. It uses a set of 22 predictors sampled during the first 48h of ICU stay to predict the probability of mortality. This set of predictors roughly corresponds to those used by the SAPS-II severity score
    ''',
    author='William Caicedo-Torres',
    url='https://github.com/williamcaicedo/ISeeU',
    keywords=['Deep Learning', 'Mortality prediction', 'Shapley values'],
    install_requires=[
        'numpy>=1.12.1',
        'pandas>=0.23.4',
        'keras>=2.2.4',
        'deeplift>=0.6.6.2',
        'matplotlib>=2.0.2',
        'tensorflow>=1.9.0'
    ],
    classifiers=[
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: MIT License',
    ],
    zip_safe=False
)
