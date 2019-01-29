from keras.models import Model, load_model
import matplotlib as mpl
import matplotlib.cm as cm
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import deeplift
from deeplift.layers import NonlinearMxtsMode
from deeplift.conversion import kerasapi_conversion as kc
from deeplift.util import compile_func


class ISeeU:
    __version__ = "0.1"

    _predictor_names = ['AGE', 'AIDS', 'BICARBONATE', 'BILIRRUBIN', 'BUN',
                        'DIASTOLIC BP', 'ELECTIVE', 'Fi02', 'GCSEyes', 'GCSMotor', 'GCSVerbal',
                        'HEART RATE', 'LYMPHOMA', 'METASTATIC CANCER', 'PO2', 'POTASSIUM', 'SODIUM',
                        'SURGICAL', 'SYSTOLIC BP', 'TEMPERATURE', 'URINE OUTPUT', 'WBC']

    _mean = np.array([[6.34243460e+01],
                      [1.15991138e-02],
                      [2.35914714e+01],
                      [2.03752342e+00],
                      [2.58391275e+01],
                      [5.91375639e+01],
                      [1.42447543e-01],
                      [2.97559969e+01],
                      [3.22050524e+00],
                      [5.25573345e+00],
                      [3.22759360e+00],
                      [8.66774736e+01],
                      [3.08875277e-02],
                      [5.55193536e-02],
                      [1.25386686e+02],
                      [4.09971018e+00],
                      [1.38761390e+02],
                      [4.43503193e-01],
                      [1.20239568e+02],
                      [3.70007987e+01],
                      [1.38921403e+02],
                      [1.27906951e+01]])

    _std = np.array([[1.57299432e+01],
                     [1.07079730e-01],
                     [4.47612455e+00],
                     [4.66545958e+00],
                     [2.08943192e+01],
                     [1.32289819e+01],
                     [3.49531348e-01],
                     [2.62710231e+01],
                     [1.10602245e+00],
                     [1.44245692e+00],
                     [1.89790566e+00],
                     [1.76732764e+01],
                     [1.73024247e-01],
                     [2.29006091e-01],
                     [6.59593339e+01],
                     [5.82762482e-01],
                     [4.62377559e+00],
                     [4.96830233e-01],
                     [2.15098339e+01],
                     [7.92864147e-01],
                     [1.72131946e+02],
                     [9.74428591e+00]])

    _palette = plt.get_cmap('tab10')

    def __init__(self):
        plt.style.use('ggplot')

        self._model = load_model(f"models/kfold{4}_best.hdf5")

        dm = kc.convert_model_from_saved_files(
            h5_file=f"models/kfold{4}_best.hdf5",
            nonlinear_mxts_mode=NonlinearMxtsMode.RevealCancel, verbose=False)
        self._deeplift_model = dm
        input_layer_name = self._deeplift_model.get_input_layer_names()[0]
        self._importance_func = self._deeplift_model.get_target_contribs_func(
            find_scores_layer_name=input_layer_name, pre_activation_target_layer_name='preact_fc2_0')

    def predict(self, patient_tensor):
        if patient_tensor.shape != (1, 22, 48):
            raise ValueError(
                "Wrong tensor shape. The patient tensor shape should be (1,22,48).")
        patient_tensor = np.nan_to_num((patient_tensor - self._mean)/self._std)
        patient_tensor = patient_tensor[:, None]
        prediction = self._model.predict(patient_tensor)
        scores = np.array(
            self._importance_func(task_idx=0, input_data_list=[patient_tensor],
                                  input_references_list=[
                                      np.zeros_like(patient_tensor)],
                                  batch_size=1, progress_update=None))
        return prediction[0][0], scores[0][0]

    def visualize_patient_scores(self, patient_tensor, importance_scores=None, cycle_colors=True, filename=None,
                                 cmap='coolwarm'):
        if patient_tensor.shape != (1, 22, 48):
            raise ValueError(
                "Wrong tensor shape. The patient tensor shape should be (1,22,48).")
        if importance_scores is not None and importance_scores.shape != (22, 48):
            raise ValueError(
                "Wrong tensor shape. The scores tensor shape should be (22,48).")
        patient_tensor = patient_tensor[0]
        if importance_scores is not None:
            norm = MidpointNormalize(vmin=importance_scores.min(
            ), vmax=importance_scores.max(), midpoint=0)
            scaled_scores = norm(importance_scores)
            heatmap_cm = cm.get_cmap(cmap)
            heatmap_colors = heatmap_cm(scaled_scores)
            colorbar_ticks = np.concatenate((np.linspace(0, importance_scores.min(), 3, endpoint=False),
                                             np.linspace(0, importance_scores.max(), 3)))

        fig, ax = plt.subplots(11, 2, sharex='col', figsize=(30, 20))
        for i, v in enumerate(self._predictor_names):
            if v in ('AIDS', 'ELECTIVE', 'METASTATIC_CANCER', 'LYMPHOMA', 'SURGICAL', 'ELECTIVE'):
                ax[int(i // 2), i % 2].set_ylim((-2, 2))

            ax[int(i // 2), i % 2].plot(range(48), patient_tensor[i],
                                        lw=2.5, color=self._palette(i % 10) if cycle_colors else self._palette(0),
                                        marker='o', markersize=6)
            ax[int(i // 2), i % 2].legend([v], loc='upper left')
            if importance_scores is not None:
                if len(heatmap_colors.shape) == 3:
                    for j in range(48):
                        ax[int(i // 2), i % 2].axvspan(j, j+1,
                                                       facecolor=heatmap_colors[i, j], alpha=0.5)
                else:
                    ax[int(i // 2), i % 2].axvspan(0, 48,
                                                   facecolor=heatmap_colors[i], alpha=0.5)

        if importance_scores is not None:
            ax_cb = fig.add_axes([0.92, 0.125, 0.015, 0.755])
            cb1 = mpl.colorbar.ColorbarBase(
                ax_cb, cmap=cmap, norm=norm, ticks=colorbar_ticks, orientation='vertical')
        plt.subplots_adjust(wspace=0.05)
        if filename is not None:
            plt.savefig(filename, dpi=200, bbox_inches='tight')
        plt.show()

    def visualize_evidence(self, importance_scores, filename=None, figsize=(20, 15)):
        if importance_scores.shape != (22, 48):
            raise ValueError(
                "Wrong tensor shape. The scores tensor shape should be (22,48).")
        norm = np.sum(np.abs(importance_scores), axis=1)
        positive_contribs = np.sum(importance_scores.clip(min=0), axis=1)
        negative_contribs = np.sum(importance_scores.clip(max=0), axis=1)
        df = pd.DataFrame(index=self._predictor_names, data={'Negative contribution': negative_contribs,
                                                             'Positive contribution': positive_contribs})
        df.plot.barh(figsize=figsize, color=[
                     self._palette(0), self._palette(3)])
        if filename is not None:
            plt.savefig(filename, dpi=200)


# set the colormap and centre the colorbar
# http://chris35wills.github.io/matplotlib_diverging_colorbar/
class MidpointNormalize(mpl.colors.Normalize):
    """
    Normalise the colorbar so that diverging bars work there way either side from a prescribed midpoint value)
    e.g. im=ax1.imshow(array, norm=MidpointNormalize(midpoint=0.,vmin=-100, vmax=100))
    """

    def __init__(self, vmin=None, vmax=None, midpoint=None, clip=False):
        self.midpoint = midpoint
        mpl.colors.Normalize.__init__(self, vmin, vmax, clip)

    def __call__(self, value, clip=None):
        x, y = [self.vmin, self.midpoint, self.vmax], [0, 0.5, 1]
        return np.ma.masked_array(np.interp(value, x, y), np.isnan(value))
