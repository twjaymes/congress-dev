import React, { useState, useEffect } from 'react';
import { Container, Typography, Box, Card, CardContent, Grid, Chip, CircularProgress } from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import ErrorIcon from '@mui/icons-material/Error';
import WarningIcon from '@mui/icons-material/Warning';

const HealthPage = () => {
  const [fastApiHealth, setFastApiHealth] = useState({ status: 'checking', data: null, error: null, responseTime: null });
  const [flaskApiHealth, setFlaskApiHealth] = useState({ status: 'checking', data: null, error: null, responseTime: null });

  const checkApiHealth = async (url, setHealthState, apiName) => {
    const startTime = Date.now();
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      const responseTime = Date.now() - startTime;
      
      if (response.ok) {
        const data = await response.json();
        setHealthState({
          status: 'healthy',
          data: data,
          error: null,
          responseTime: responseTime
        });
      } else {
        setHealthState({
          status: 'error',
          data: null,
          error: `HTTP ${response.status}: ${response.statusText}`,
          responseTime: responseTime
        });
      }
    } catch (error) {
      const responseTime = Date.now() - startTime;
      setHealthState({
        status: 'error',
        data: null,
        error: error.message,
        responseTime: responseTime
      });
    }
  };

  useEffect(() => {
    // Check FastAPI health - get first member
    checkApiHealth('http://localhost:9001/members?page=1&page_size=1', setFastApiHealth, 'FastAPI');
    
    // Check Flask API health - get bill list
    checkApiHealth('http://localhost:9000/bill?page=1&page_size=1', setFlaskApiHealth, 'Flask API');
    
    // Set up polling every 30 seconds
    const interval = setInterval(() => {
      checkApiHealth('http://localhost:9001/members?page=1&page_size=1', setFastApiHealth, 'FastAPI');
      checkApiHealth('http://localhost:9000/bill?page=1&page_size=1', setFlaskApiHealth, 'Flask API');
    }, 30000);
    
    return () => clearInterval(interval);
  }, []);

  const renderStatusIcon = (status) => {
    switch (status) {
      case 'healthy':
        return <CheckCircleIcon sx={{ color: 'success.main', fontSize: 40 }} />;
      case 'error':
        return <ErrorIcon sx={{ color: 'error.main', fontSize: 40 }} />;
      case 'checking':
        return <CircularProgress size={40} />;
      default:
        return <WarningIcon sx={{ color: 'warning.main', fontSize: 40 }} />;
    }
  };

  const renderStatusChip = (status) => {
    const chipProps = {
      healthy: { label: 'Healthy', color: 'success' },
      error: { label: 'Error', color: 'error' },
      checking: { label: 'Checking...', color: 'default' },
    };
    
    return <Chip {...(chipProps[status] || { label: 'Unknown', color: 'warning' })} />;
  };

  const ApiHealthCard = ({ title, health, endpoint }) => (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
          <Typography variant="h6" component="div">
            {title}
          </Typography>
          {renderStatusIcon(health.status)}
        </Box>
        
        <Box mb={2}>
          {renderStatusChip(health.status)}
        </Box>
        
        <Typography variant="body2" color="text.secondary" gutterBottom>
          <strong>Endpoint:</strong> {endpoint}
        </Typography>
        
        {health.responseTime && (
          <Typography variant="body2" color="text.secondary" gutterBottom>
            <strong>Response Time:</strong> {health.responseTime}ms
          </Typography>
        )}
        
        {health.error && (
          <Box mt={2} p={1} bgcolor="error.light" borderRadius={1}>
            <Typography variant="body2" color="error.dark">
              <strong>Error:</strong> {health.error}
            </Typography>
          </Box>
        )}
        
        {health.data && (
          <Box mt={2}>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              <strong>Sample Data:</strong>
            </Typography>
            <Box 
              component="pre" 
              sx={{ 
                bgcolor: 'grey.100', 
                p: 1, 
                borderRadius: 1, 
                fontSize: '0.75rem',
                overflow: 'auto',
                maxHeight: '200px'
              }}
            >
              {JSON.stringify(health.data, null, 2)}
            </Box>
          </Box>
        )}
      </CardContent>
    </Card>
  );

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        API Health Dashboard
      </Typography>
      
      <Typography variant="body1" color="text.secondary" paragraph>
        Monitor the health status of Congress.dev APIs. This page automatically checks the APIs every 30 seconds.
      </Typography>
      
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <ApiHealthCard 
            title="FastAPI (v2)"
            health={fastApiHealth}
            endpoint="http://localhost:9001/members"
          />
        </Grid>
        
        <Grid item xs={12} md={6}>
          <ApiHealthCard 
            title="Flask API (v1)"
            health={flaskApiHealth}
            endpoint="http://localhost:9000/bill"
          />
        </Grid>
      </Grid>
      
      <Box mt={4} p={2} bgcolor="info.light" borderRadius={1}>
        <Typography variant="body2" color="info.dark">
          <strong>Note:</strong> This health check fetches a single row from each API to verify connectivity and response.
          Green status indicates the API is responding correctly. Red status indicates an error or connectivity issue.
        </Typography>
      </Box>
    </Container>
  );
};

export default HealthPage;