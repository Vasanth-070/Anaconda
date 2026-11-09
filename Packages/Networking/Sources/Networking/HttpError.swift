import Foundation

/// Transport-level failures, mapped once in the HTTP layer so feature clients
/// never look at URLError or raw status codes.
public enum HttpError: Error, Equatable, Sendable {
  case offline
  case cancelled
  case connection
  case unauthorized
  case notFound
  case status(Int)
  case invalidResponse
}
