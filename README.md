# Registration App

A full-stack user registration and authentication application built with React frontend and Python FastAPI backend.






## 🏗️ High Architecture

![High Level Architecture](https://github.com/emanet1/registration-app/blob/8a81133aa78e65b90fb24daff2a96fe3754932ec/images/high-level-arch.png)



## 🏗️ Low Architecture

![Low Level Architecture](https://github.com/emanet1/registration-app/blob/4644d4a56d5ac975537669b9d834bd72089a070b/images/low-level-arch.png)






### Backend (Python FastAPI)
- **Technology**: FastAPI with Python 3.9
- **Port**: 8000 (mapped to 9091 externally)
- **Authentication**: JWT token-based authentication
- **Password Security**: bcrypt hashing
- **CORS**: Enabled for frontend communication

### Frontend (React)
- **Technology**: React 18 with Material-UI
- **Port**: 3000 (mapped to 9090 externally)
- **State Management**: React Context API
- **Routing**: React Router DOM
- **UI Framework**: Material-UI (MUI)

### Database
- **Technology**: PostgreSQL 13
- **Port**: 5432 (mapped to 9092 externally)
- **Status**: Configured but backend currently uses in-memory storage

## 🚀 Features

### Backend API Endpoints
- `POST /api/register` - User registration
- `POST /api/token` - User login (OAuth2)
- `GET /api/users/me` - Get current user info (protected)
- `GET /api/health` - Health check

### Frontend Components
- **Login Page** - User authentication
- **Registration Page** - New user signup
- **Dashboard** - Protected user dashboard
- **Auth Context** - Authentication state management

## 📋 Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local development)
- Python 3.9+ (for local development)

## 🛠️ Installation & Setup

### Using Docker (Recommended)

1. **Clone the repository**
   ```bash
   git clone https://github.com/emanet1/registration-app.git
   cd registration-app
   ```

2. **Create environment file**
   ```bash
   # Create .env file in the root directory
   echo "JWT_SECRET_KEY=your-secret-key-here" > .env
   ```

3. **Build and run with Docker Compose**
   ```bash
   docker-compose up --build
   ```

4. **Access the application**
   - Frontend: http://localhost:9090
   - Backend API: http://localhost:9091
   - Database: localhost:9092

### Local Development

#### Backend Setup
```bash
cd backend
python -m pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

#### Correct URLs to Test

 ### API Documentation (Swagger UI):
```
http://localhost:8000/docs
```

### Health Check:
```
http://localhost:8000/api/health
```



#### Frontend Setup
```bash
cd frontend
npm install
# Set environment variable
export REACT_APP_API_URL=http://localhost:8000
npm start
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# JWT Secret Key for token signing
JWT_SECRET_KEY=your-secret-key-here

# Database Configuration (if using real database)
DB_HOST=db
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=magax
```

### Frontend Environment

The frontend expects the following environment variable:
- `REACT_APP_API_URL` - Backend API URL (default: http://localhost:9091)


### Build Backend Image using Docker
```
docker build -t reg-backend .
```

### Build frontend Image using single stage build
```
docker build -t reg-frontend-single:latest --build-arg REACT_APP_API_URL=http://localhost:8000 .
```


### Build FrontEnd Image using Docker
```
docker build --build-arg REACT_APP_API_URL=http://localhost:8000 -t frontend .
```

### RUN Backend using Docker
```
docker run -d --name reg-backend -p 8000:8000 reg-backend
```

### RUN Frontend using Docker
```
docker run -d --name reg-frontend -p 3000:3000 frontend:latest
```

### Exec into the Containers
```
docker exec -it reg-frontend sh
docker exec -it reg-backend sh
```


# What are Docker Volumes?

In Docker, a volume is a persistent storage mechanism for containers. By default, any data created inside a container is ephemeral—it disappears when the container stops or is removed. Volumes solve this problem by providing:

Persistence: Data survives container restarts or removals.

Sharing: Multiple containers can access the same data.

Separation of concerns: Keeps container filesystem clean while storing data outside.

Volumes are stored on the host filesystem but managed by Docker.



# Types of Docker Storage

Volumes – Recommended. Managed by Docker, easy to back up and share.

Bind mounts – Directly map host directory to container. Gives more control but less portable.

Tmpfs mounts – Stored in host RAM, non-persistent.

We’ll focus on volumes & Bing Mounts


## We’ll use volumes and bind mounts  reg-backend (FastAPI) and reg-frontend (Nginx).


## Create a named volume

```
docker volume create backend_data
docker volume ls
```

## Use a volume in your backend container
Persist files at /data inside reg-backend:

```
docker rm -f reg-backend
docker run -d --name reg-backend -p 8000:8000 -v backend_data:/data reg-backend
```

 !!! Anything written to /data will survive container removal.


### Quick persistence check:

```
docker exec -it reg-backend sh -c "echo hello > /data/hello.txt && ls -l /data"
docker rm -f reg-backend
docker run -d --name reg-backend -p 8000:8000 -v backend_data:/data reg-backend
docker exec -it reg-backend sh -c "cat /data/hello.txt"
```


##Bind mount (live-edit) your backend code
Mount your local backend folder into the container:

```
docker rm -f reg-backend
MSYS_NO_PATHCONV=1 docker run -d --name reg-backend -p 8000:8000 \
  -v "C:/Users/user/Documents/Organization/DIGITAL-WITCH/DOCKER/practical-class/registration-app/backend:/app" \
  reg-backend
docker exec -it reg-backend sh -c 'echo hi > /app/test.txt'
```


## 📁 Project Structure

```
registration-app/
├── backend/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile          # Backend Docker configuration
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Login.js     # Login component
│   │   │   ├── Register.js  # Registration component
│   │   │   └── Dashboard.js # Dashboard component
│   │   ├── contexts/
│   │   │   └── AuthContext.js # Authentication context
│   │   ├── App.js           # Main App component
│   │   └── index.js         # Entry point
│   ├── package.json         # Frontend dependencies
│   ├── Dockerfile          # Frontend Docker configuration
│   └── nginx.conf          # Nginx configuration
├── docker-compose.yml      # Docker services configuration
└── README.md              # This file
```

## 🔐 Authentication Flow

1. **Registration**: User creates account with username, email, and password
2. **Login**: User authenticates with username/password
3. **Token**: Backend returns JWT token
4. **Storage**: Frontend stores token in localStorage
5. **Protected Routes**: Token used for API calls and route protection

## 🐳 Docker Services

| Service | Port | Description |
|---------|------|-------------|
| frontend | 9090 | React application |
| backend | 9091 | FastAPI application |
| db | 9092 | PostgreSQL database |

## 🚨 Known Issues

1. **In-Memory Storage**: Backend currently uses in-memory storage instead of PostgreSQL
2. **No Database Persistence**: User data is lost on server restart
3. **Missing Environment Setup**: .env file needs to be created manually

## 🔄 Development Commands

### Backend
```bash
# Run with auto-reload
uvicorn main:app --reload

# Run with specific host/port
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Frontend
```bash
# Start development server
npm start

# Build for production
npm run build

# Run tests
npm test
```

### Docker
```bash
# Build and start all services
docker-compose up --build

# Start in background
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f
```

## 🧪 Testing

### Backend API Testing
```bash
# Health check
curl http://localhost:9091/api/health

# Register user
curl -X POST http://localhost:9091/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"testpass"}'

# Login
curl -X POST http://localhost:9091/api/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=testpass"
```


## More Docker-Compose real world Examples
```
visit https://github.com/docker/awesome-compose
```



## 📝 API Documentation

Once the backend is running, you can access the interactive API documentation at:
- Swagger UI: http://localhost:9091/docs
- ReDoc: http://localhost:9091/redoc

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support


For support and questions, please open an issue in the repository or contact the development team.


lets get it done and run the code



# Create S3 bucket
aws s3api create-bucket \
  --bucket youngyz-registration-app-958421185668 \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket youngyz-registration-app-958421185668 \
  --versioning-configuration Status=Enabled

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name registration-app-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

  
cd ~/registration-app/terraform
terraform output app_url

Connect to EC2
ssh -i ~/.ssh/jenkins.pem ec2-user@54.221.166.98

Check containers are running
sudo docker ps

Check container logs for errors
sudo docker logs registration-app-backend --tail 50
sudo docker logs registration-app-frontend --tail 50

Check database connection
sudo docker exec registration-app-backend python -c "from database import engine; print('DB connected:', engine.url)"

Check memory usage
free -h

Check Docker resource usage
bashsudo docker stats --no-stream

Check ECR login still valid
sudo docker system info | grep Registry