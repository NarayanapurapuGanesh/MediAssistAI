from sklearn.ensemble import IsolationForest
import numpy as np
from typing import List

class AnomalyDetector:
    def __init__(self, contamination=0.1):
        # contamination sets the expected proportion of outliers
        self.model = IsolationForest(contamination=contamination, random_state=42)

    def analyze_trend(self, measurements: List) -> bool:
        """
        Returns True if the most recent measurement is considered an anomaly.
        Requires at least a few measurements to build a baseline.
        """
        if len(measurements) < 5:
            return False # Not enough data
            
        features = []
        for m in measurements:
            if getattr(m, 'secondary_value', None) is not None:
                features.append([m.value, m.secondary_value])
            else:
                features.append([m.value, 0])
                
        values = np.array(features)
        
        # Train on all data
        self.model.fit(values)
        
        # Predict: 1 for normal, -1 for anomaly
        predictions = self.model.predict(values)
        
        # Return True if the last measurement is an anomaly
        return predictions[-1] == -1
