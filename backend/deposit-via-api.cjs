const http = require('http');

// API'ye POST request gönder
function makeApiRequest(amount) {
  const data = JSON.stringify({
    amount: amount,
    note: 'Mevcut parayı hedeflere dağıtım'
  });

  const options = {
    hostname: '192.168.1.21',
    port: 3000,
    path: '/api/accounts/685bba3aadcfbbf856613ed3/deposit',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2ODViYmRlZTNkNzNiZWY0ODViZDI3OTEiLCJpYXQiOjE3NTA4NTA5NjUsImV4cCI6MTc1MTQ1NTc2NX0.K8RCBnfFrY60GiM8iU4-w-nAD6S8XjQCWhGi4ToNtSg',
      'Content-Length': data.length
    }
  };

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    
    let body = '';
    res.on('data', (chunk) => {
      body += chunk;
    });
    
    res.on('end', () => {
      try {
        const result = JSON.parse(body);
        console.log('Response:', result);
      } catch (e) {
        console.log('Raw response:', body);
      }
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
  });

  req.write(data);
  req.end();
}

console.log('API\'ye 1000₺ deposit isteği gönderiliyor...');
makeApiRequest(1000); 