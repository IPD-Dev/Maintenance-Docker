FROM eclipse-temurin:17-jdk-alpine as velocity-builder
RUN apk --no-cache add git 
WORKDIR /build/

RUN git clone https://github.com/PaperMC/Velocity.git --depth=1

WORKDIR /build/Velocity
RUN ./gradlew --no-daemon shadowJar --stacktrace --info

FROM eclipse-temurin:8-jdk-alpine as maintenance-builder
RUN apk --no-cache add git

WORKDIR /build/
RUN git clone https://github.com/kennytv/Maintenance.git --depth=1

WORKDIR /build/Maintenance
RUN ./gradlew --no-daemon maintenance-velocity:shadowJar --stacktrace --info

FROM alpine as proxy-builder

WORKDIR /server/

COPY --from=velocity-builder /build/Velocity/proxy/build/libs/*all.jar proxy.jar
ADD velocity.toml /server/velocity.toml
RUN echo "UNUSED" > forwarding-secret

WORKDIR /server/plugins

COPY --from=maintenance-builder /build/Maintenance/build/libs/*.jar Maintenance.jar

WORKDIR /server/plugins/maintenance
ADD config.yml .
ADD maintenance-icon.png .

RUN addgroup -g 1000 nonroot
RUN adduser -S -H -D -u 1000 nonroot nonroot
RUN chown -R nonroot:nonroot /server/
RUN chmod -R 777 /server/

FROM gcr.io/distroless/java17-debian11:nonroot
USER nonroot:nonroot

COPY --chown=nonroot:nonroot --from=proxy-builder /server/ /server/

WORKDIR /server/
ENTRYPOINT [ "java", "-Xms1G", "-Xmx1G", "-XX:+UseG1GC", "-XX:G1HeapRegionSize=4M", "-XX:+UnlockExperimentalVMOptions", "-XX:+ParallelRefProcEnabled", "-XX:+AlwaysPreTouch", "-XX:MaxInlineLevel=15", "-jar", "proxy.jar" ]
