#define trigPin1 15
#define trigPin2 12
#define echoPin1 13
#define echoPin2 14
#define background 33
#define lane 30

//below pins used to offload data when shorted
#define out 16
#define in 2

bool car = false;
long avgdistance = 0;
const short memlen = 100;
short distances[memlen] = {0};
short numavged = 0;
short i = 0;
short data[300];
short signalLengths[300];
short nzeros[300];
short entry = 0;

void setup() {
  //init arrays
  for(int i=0;i<300;i++)
  { data[i] = -1;
    signalLengths[i] = -1;
    nzeros[i] = -1;}

  Serial.begin(9600);
  Serial.println("Serial Begin");
  pinMode(trigPin1, OUTPUT);
  pinMode(trigPin2, OUTPUT);
  pinMode(echoPin1, INPUT);
  pinMode(echoPin2, INPUT);
  pinMode(out, OUTPUT);
  pinMode(in, INPUT);
  digitalWrite(out, LOW);
} 

void loop() {
  delay(100);
  long t1, t2, d1, d2;
  digitalWrite(trigPin1, LOW);
  digitalWrite(trigPin2, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin1, HIGH);
  digitalWrite(trigPin2, HIGH);
  delayMicroseconds(2); 
  digitalWrite(trigPin1, LOW); //PING SENSOR
  t1 = pulseIn(echoPin1, HIGH);
  digitalWrite(trigPin2, LOW);
  t2 = pulseIn(echoPin2, HIGH); //RECORD ECHO TIME
  d1 = (t1/2) / 29.1;
  d2 = (t2/2) / 29.1; //CONVERT TO CM

  if(digitalRead(in) == LOW) //PRINT ALL DATA WHEN IN AND OUT PINS SHORTED
  {int ridx = 0;
    for(int p = 0; p<1; p++)
      Serial.println("######### PRINTING PASSING DATA #########");
    while(data[ridx] != -1 && ridx<300)
      {Serial.println(data[ridx++]);}}    

  if(car) { 
    if(d1>=background && d2>=background) { //CHECK IF CAR HAS LEFT THE SENSOR RANGE
      car = false;
      if(i > 0) //INCLUDE UNAGGREGATED SAMPLES
      {
        int sum = 0;
        for (int ii = 0; ii < i; ii++)
        { sum += distances[ii];}
        if (numavged == 0)
        { avgdistance = sum/i;}
      }
      Serial.print("Detected Object passing at ");
      Serial.print(avgdistance);
      Serial.println("cm.");
      signalLengths[entry] = numavged; //RECORD CAR'S AVERAGE DISTANCE
      data[entry++] = avgdistance;
      avgdistance = 0;
      numavged = 0;
      memset(distances, 0, memlen);
      i = 0;
    } else {
      if(i==memlen){ //UPDATE AVERAGE AND CLEAR CURRENT DISTANCE MEMORY WHEN FULL
        Serial.println("Setting average distance.");
        i = 0;
        int sum = 0;
        for (int ii = 0; ii < memlen; ii++)
          {sum += distances[ii];}
        Serial.println(sum/memlen);
        avgdistance = avgdistance*numavged + sum/memlen;
        numavged += 1;
        avgdistance/=numavged;
      } 
      if(d1 == 0 || d2 == 0) //CHECK IF A SENSOR IS DOWN
      { if (d1 == 0 && d2 == 0)
        { nzeros[entry] += 2;}
        else
        { nzeros[entry] += 1;}}
      else if(d1 < background && d2 < background) //RECORD OBJECT DISTANCE SAMPLE
      { distances[i] = (d1 + d2)/2; }
      else if(d1 < background)
      { distances[i] = d1; }
      else
      { distances[i] = d2; }
      Serial.print("Reading car distance: ");
      Serial.println(distances[i]);
      Serial.println(i);
      i++;
    }
  } else if(d1<lane && d2<lane) { //CHECK IF SENSOR IS DETECTING A CAR
    Serial.print("Reading car distances: ");
    Serial.print(d1);
    Serial.print(",");
    Serial.println(d2);
    car = true;
  }
}
