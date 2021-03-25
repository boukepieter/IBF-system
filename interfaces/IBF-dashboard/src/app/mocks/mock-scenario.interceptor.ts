import {
  HttpEvent,
  HttpHandler,
  HttpInterceptor,
  HttpRequest,
} from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MockScenarioService } from 'src/app/mocks/mock-scenario-service/mock-scenario.service';
import { environment } from 'src/environments/environment';
import { MockAPI } from './api.mock';
import { MockScenario } from './mock-scenario.enum';

@Injectable({
  providedIn: 'root',
})
export class MockScenarioInterceptor implements HttpInterceptor {
  private mockScenario: MockScenario;

  constructor(
    private mockScenarioService: MockScenarioService,
    private mockAPI: MockAPI,
  ) {
    this.mockScenarioService
      .getMockScenarioSubscription()
      .subscribe((mockScenario: MockScenario) => {
        this.mockScenario = mockScenario;
      });
  }

  intercept(
    request: HttpRequest<any>,
    next: HttpHandler,
  ): Observable<HttpEvent<any>> {
    // Strip API-hostname from url:
    const requestPath = request.url.replace(environment.apiUrl, '');
    // Use only first level to get generic endpoint
    const requestPathSplit = requestPath.split('/');
    const requestEndpoint = requestPathSplit[1];

    let mockAPIs = this.mockAPI.getMockAPI();
    if (
      requestEndpoint === 'stations' ||
      requestEndpoint === 'admin-area-data'
    ) {
      const leadTime = requestPathSplit[requestPathSplit.length - 1];
      mockAPIs = this.mockAPI.getMockAPI(leadTime);
    }

    const currentMockEndpoint =
      (mockAPIs[request.method] && mockAPIs[request.method][requestPath]) ||
      (mockAPIs[request.method] && mockAPIs[request.method][requestEndpoint]) ||
      null;

    const isMockScenario = this.mockScenario !== MockScenario.real;

    return isMockScenario && currentMockEndpoint
      ? currentMockEndpoint.handler()
      : next.handle(request);
  }
}
