import axios from 'axios';

const API_URL = 'http://localhost:8000';

const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

console.log(`📡 API Initialized with base URL: ${API_URL}`);

export const loginUser = async (reg_no_or_email, password) => {
    try {
        const response = await api.post('/login', {
            reg_no_or_email,
            password,
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Login failed. Please check your credentials.';
    }
};

export const sendOtp = async (target, isRegistration = true) => {
    try {
        const response = await api.post('/send_otp', {
            target,
            is_registration: isRegistration
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to send OTP.';
    }
};

export const verifyOtp = async (target, code, isRegistration = true, isAdmin = false) => {
    try {
        const response = await api.post('/verify_otp', {
            target,
            code,
            is_registration: isRegistration,
            is_admin: isAdmin,
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'OTP verification failed.';
    }
};

export const registerStudent = async (studentData) => {
    try {
        const response = await api.post('/register', studentData);
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Registration failed.';
    }
};

export const getStops = async () => {
    try {
        const response = await api.get('/stops');
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch stops.';
    }
};

export const searchTrips = async (fromStopName, toStopName) => {
    try {
        const response = await api.get('/api/routes/search', {
            params: { from_stop: fromStopName, to_stop: toStopName }
        });
        // The backend returns { ok: true, data: [...] }
        return response.data;
    } catch (error) {
        console.error("API Search Error:", error);
        throw error.response?.data?.detail || 'Failed to search trips.';
    }
};

export const getRouteStops = async (routeId, direction) => {
    try {
        const response = await api.get('/api/stops', {
            params: { rt: routeId, dir: direction }
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch route stops.';
    }
};

export const getSearchSuggestions = async (query) => {
    try {
        const response = await api.get('/api/search/suggestions', {
            params: { q: query }
        });
        return response.data;
    } catch (error) {
        console.error("Suggestions Error:", error);
        return { ok: false, suggestions: [] };
    }
};

export const getNearbyStops = async (lat, lon) => {
    try {
        const response = await api.get('/api/stops/nearby', {
            params: { lat, lon, directions: true }
        });
        return response.data;
    } catch (error) {
        console.error("Nearby Stops Error:", error);
        return { ok: false, data: [] };
    }
};

export const getLatestGPS = async (tripId) => {
    try {
        const response = await api.get('/gps/latest', {
            params: { trip_id: tripId }
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch latest GPS.';
    }
};

export const trackBusByNumber = async (busNo) => {
    try {
        const response = await api.get(`/api/bus/track/${busNo}`);
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || `Failed to track bus #${busNo}.`;
    }
};

export const getLiveFleet = async () => {
    try {
        const response = await api.get('/api/gps/live');
        return response.data;
    } catch (error) {
        console.error("Live Fleet Error:", error);
        return { ok: false, data: [] };
    }
};

export const getTripTimeline = async (tripId, fromStopId = null, toStopId = null) => {
    try {
        const response = await api.get('/api/trip/timeline', {
            params: { trip_id: tripId, from_stop_id: fromStopId, to_stop_id: toStopId }
        });
        return response.data;
    } catch (error) {
        throw error.response?.data?.detail || 'Failed to fetch trip timeline.';
    }
};

export default api;
