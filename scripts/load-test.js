import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const successRate = new Rate('success');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 50 },  // Ramp up to 50 users
    { duration: '5m', target: 50 },  // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate must be below 10%
    errors: ['rate<0.1'],             // Custom error rate must be below 10%
    success: ['rate>0.9'],            // Success rate must be above 90%
  },
};

// Test data
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const USERS = [
  { id: 1, username: 'john.doe', email: 'john.doe@example.com' },
  { id: 2, username: 'jane.smith', email: 'jane.smith@example.com' },
  { id: 3, username: 'admin', email: 'admin@example.com' },
];

const PRODUCTS = [
  { id: 1, name: 'Laptop Pro', price: 1299.99 },
  { id: 2, name: 'Wireless Mouse', price: 29.99 },
  { id: 3, name: 'USB Cable', price: 9.99 },
  { id: 4, name: 'Monitor 24"', price: 199.99 },
];

// Helper functions
function getRandomUser() {
  return USERS[Math.floor(Math.random() * USERS.length)];
}

function getRandomProduct() {
  return PRODUCTS[Math.floor(Math.random() * PRODUCTS.length)];
}

function getRandomOrder() {
  const user = getRandomUser();
  const product = getRandomProduct();
  const quantity = Math.floor(Math.random() * 5) + 1;
  
  return {
    userId: user.id,
    items: [{
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      unitPrice: product.price,
      totalPrice: product.price * quantity
    }],
    totalAmount: product.price * quantity,
    shippingAddress: '123 Main St, City, Country',
    billingAddress: '123 Main St, City, Country',
    paymentMethod: 'CREDIT_CARD'
  };
}

// Main test scenarios
export default function() {
  const user = getRandomUser();
  const order = getRandomOrder();
  
  // Test 1: Health Check
  const healthCheck = http.get(`${BASE_URL}/actuator/health`);
  check(healthCheck, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  if (healthCheck.status !== 200) {
    errorRate.add(1);
    return;
  }
  
  // Test 2: User Service - Get User
  const getUserResponse = http.get(`${BASE_URL}/api/users/${user.id}`);
  check(getUserResponse, {
    'get user status is 200': (r) => r.status === 200,
    'get user response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  if (getUserResponse.status !== 200) {
    errorRate.add(1);
  } else {
    successRate.add(1);
  }
  
  // Test 3: Product Service - Get Products
  const getProductsResponse = http.get(`${BASE_URL}/api/products`);
  check(getProductsResponse, {
    'get products status is 200': (r) => r.status === 200,
    'get products response time < 400ms': (r) => r.timings.duration < 400,
  });
  
  if (getProductsResponse.status !== 200) {
    errorRate.add(1);
  } else {
    successRate.add(1);
  }
  
  // Test 4: Order Service - Create Order
  const createOrderResponse = http.post(`${BASE_URL}/api/orders`, JSON.stringify(order), {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${user.id}`,
    },
  });
  
  check(createOrderResponse, {
    'create order status is 201': (r) => r.status === 201,
    'create order response time < 1000ms': (r) => r.timings.duration < 1000,
  });
  
  if (createOrderResponse.status !== 201) {
    errorRate.add(1);
  } else {
    successRate.add(1);
    
    // Test 5: Order Service - Get Order
    const orderId = createOrderResponse.json('id');
    if (orderId) {
      const getOrderResponse = http.get(`${BASE_URL}/api/orders/${orderId}`);
      check(getOrderResponse, {
        'get order status is 200': (r) => r.status === 200,
        'get order response time < 500ms': (r) => r.timings.duration < 500,
      });
      
      if (getOrderResponse.status !== 200) {
        errorRate.add(1);
      } else {
        successRate.add(1);
      }
    }
  }
  
  // Test 6: Payment Service - Process Payment
  const payment = {
    orderId: Math.floor(Math.random() * 1000) + 1,
    amount: order.totalAmount,
    paymentMethod: 'CREDIT_CARD',
    cardNumber: '4111111111111111',
    expiryDate: '12/25',
    cvv: '123'
  };
  
  const processPaymentResponse = http.post(`${BASE_URL}/api/payments`, JSON.stringify(payment), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  check(processPaymentResponse, {
    'process payment status is 200': (r) => r.status === 200,
    'process payment response time < 800ms': (r) => r.timings.duration < 800,
  });
  
  if (processPaymentResponse.status !== 200) {
    errorRate.add(1);
  } else {
    successRate.add(1);
  }
  
  // Test 7: Inventory Service - Check Stock
  const product = getRandomProduct();
  const checkStockResponse = http.get(`${BASE_URL}/api/inventory/products/${product.id}/stock`);
  
  check(checkStockResponse, {
    'check stock status is 200': (r) => r.status === 200,
    'check stock response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  if (checkStockResponse.status !== 200) {
    errorRate.add(1);
  } else {
    successRate.add(1);
  }
  
  // Test 8: Notification Service - Send Notification
  const notification = {
    userId: user.id,
    type: 'EMAIL',
    title: 'Order Confirmation',
    message: 'Your order has been confirmed'
  };
  
  const sendNotificationResponse = http.post(`${BASE_URL}/api/notifications`, JSON.stringify(notification), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  check(sendNotificationResponse, {
    'send notification status is 200': (r) => r.status === 200,
    'send notification response time < 600ms': (r) => r.timings.duration < 600,
  });
  
  if (sendNotificationResponse.status !== 200) {
    errorRate.add(1);
  } else {
    successRate.add(1);
  }
  
  // Think time between requests
  sleep(1);
}

// Setup function for test initialization
export function setup() {
  console.log('Starting load test for microservices platform');
  console.log(`Base URL: ${BASE_URL}`);
  console.log('Test configuration:');
  console.log('- Ramp up to 100 users over 21 minutes');
  console.log('- 95% of requests must complete below 500ms');
  console.log('- Error rate must be below 10%');
  console.log('- Success rate must be above 90%');
}

// Teardown function for cleanup
export function teardown(data) {
  console.log('Load test completed');
  console.log('Results:');
  console.log(`- Total requests: ${data.metrics.http_reqs.values.count}`);
  console.log(`- Average response time: ${data.metrics.http_req_duration.values.avg}ms`);
  console.log(`- 95th percentile: ${data.metrics.http_req_duration.values['p(95)']}ms`);
  console.log(`- Error rate: ${data.metrics.http_req_failed.values.rate * 100}%`);
} 